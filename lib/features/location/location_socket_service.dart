import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_compass/flutter_compass.dart';

import 'package:atlocator/core/config/app_config.dart';
import 'package:atlocator/features/auth/session/auth_session.dart';
import 'package:atlocator/features/location/foreground_task.dart';

class LocationSocketService {
  LocationSocketService._();

  static final instance = LocationSocketService._();

  io.Socket? _socket;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _started = false;
  LocationSocketSnapshot _snapshot = LocationSocketSnapshot.initial();

  final ValueNotifier<LocationSocketSnapshot> snapshotNotifier = ValueNotifier(
    LocationSocketSnapshot.initial(),
  );

  bool get isStarted => _started;
  bool get isConnected => _socket?.connected ?? false;
  LocationSocketSnapshot get snapshot => _snapshot;

  Future<void> start({
    int? userId,
    int tripId = 0,
    String roomId = "",
  }) async {
    final resolvedUserId = userId ?? AuthSession.userId;
    if (resolvedUserId == null) return;

    if (_started) {
      if (_snapshot.tripId == tripId && _snapshot.roomId == roomId) return;
      await stop();
    }

    _started = true;
    _updateSnapshot(
      _snapshot.copyWith(
        userId: resolvedUserId,
        tripId: tripId,
        roomId: roomId,
        isStarted: true,
      ),
    );

    await _startForegroundTask();
    _connectSocket(roomId);
    await _startLocationUpdates(
      userId: resolvedUserId,
      tripId: tripId,
      roomId: roomId,
    );
  }

  Future<void> stop() async {
    await _stopForegroundTask();
    _started = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _compassSubscription?.cancel();
    _compassSubscription = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateSnapshot(LocationSocketSnapshot.initial());
  }

  void _connectSocket(String roomId) {
    final token = AuthSession.token;
    final normalizedPath = _normalizeSocketPath(AppConfig.socketPath);

    final options = io.OptionBuilder()
        .setTransports(["websocket", "polling"])
        .disableAutoConnect()
        .setPath(normalizedPath)
        .setAuth({if (token != null && token.isNotEmpty) "token": token})
        .build();

    _socket = io.io(AppConfig.socketBaseUrl, options);
    _socket
      ?..onConnect((_) {
        debugPrint("Socket connected to ${AppConfig.socketBaseUrl}$normalizedPath");
        _updateSnapshot(_snapshot.copyWith(isConnected: true));
        if (roomId.trim().isNotEmpty) {
          _joinRoom(roomId);
        }
      })
      ..onConnectError((error) {
        debugPrint("Socket connection failed: $error");
        _updateSnapshot(_snapshot.copyWith(isConnected: false));
      })
      ..onError((error) {
        debugPrint("Socket runtime error: $error");
      })
      ..on("members", (data) {
        try {
          if (data == null) return;

          Map<int, MemberLocation> members = {};

          if (data is String) {
            final decoded = jsonDecode(data);
            if (decoded is List) {
              for (final item in decoded) {
                if (item is Map) {
                  final userId = int.tryParse(item['userId']?.toString() ?? '') ?? 0;
                  if (userId <= 0) continue;
                  members[userId] = MemberLocation.fromMap(Map<String, dynamic>.from(item));
                }
              }
            }
          } else if (data is List) {
            for (final item in data) {
              if (item is Map) {
                final userId = int.tryParse(item['userId']?.toString() ?? '') ?? 0;
                if (userId <= 0) continue;
                members[userId] = MemberLocation.fromMap(Map<String, dynamic>.from(item));
              }
            }
          } else if (data is Map) {
            // maybe wrapped in { "members": [...] }
            final maybeList = data['members'] ?? data['data'] ?? data['items'];
            if (maybeList is List) {
              for (final item in maybeList) {
                if (item is Map) {
                  final userId = int.tryParse(item['userId']?.toString() ?? '') ?? 0;
                  if (userId <= 0) continue;
                  members[userId] = MemberLocation.fromMap(Map<String, dynamic>.from(item));
                }
              }
            }
          }

          if (members.isNotEmpty) {
            final merged = Map<int, MemberLocation>.from(_snapshot.members);
            merged.addAll(members);
            _updateSnapshot(_snapshot.copyWith(members: merged));
          }
        } on Object catch (_) {
          // ignore
        }
      })
      ..on("member-joined", (data) {
        _handleRemoteLocation(data);
      })
      ..on("member-left", (data) {
        try {
          int id = 0;
          if (data is Map) id = int.tryParse(data['userId']?.toString() ?? '') ?? 0;
          if (data is String) {
            final d = jsonDecode(data);
            if (d is Map) id = int.tryParse(d['userId']?.toString() ?? '') ?? 0;
          }
          if (id > 0) {
            final members = Map<int, MemberLocation>.from(_snapshot.members);
            members.remove(id);
            _updateSnapshot(_snapshot.copyWith(members: members));
          }
        } on Object catch (_) {}
      })
      ..on("user-location", (data) {
        _handleRemoteLocation(data);
      })
      ..on("location", (data) {
        _handleRemoteLocation(data);
      })
      ..onDisconnect((reason) {
        debugPrint("Socket disconnected: $reason");
        _updateSnapshot(_snapshot.copyWith(isConnected: false));
      })
      ..onReconnect((_) {
        debugPrint("Socket reconnected");
        _updateSnapshot(_snapshot.copyWith(isConnected: true));
        _joinRoom(roomId);
      })
      ..connect();
    // Start compass subscription so UI heading follows device orientation
    _startCompass();
  }

  void _startCompass() {
    final events = FlutterCompass.events;
    if (events == null) return;

    _compassSubscription?.cancel();
    _compassSubscription = events.listen((event) {
      final heading = event.heading;
      if (heading == null || !heading.isFinite) return;

      final current = _snapshot.latestLocation;
      if (current == null) return;

      final updated = LocationTelemetry(
        latitude: current.latitude,
        longitude: current.longitude,
        speedKmh: current.speedKmh,
        heading: heading.round(),
        accuracy: current.accuracy,
        recordedAt: current.recordedAt,
      );

      _updateSnapshot(_snapshot.copyWith(latestLocation: updated));
    });
  }

  String _normalizeSocketPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return "/socket.io";
    return trimmed.startsWith("/") ? trimmed : "/$trimmed";
  }

  Future<void> _startLocationUpdates({
    required int userId,
    required int tripId,
    required String roomId,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 12));
      _handlePosition(position, userId: userId, tripId: tripId, roomId: roomId);
    } on Object {
      // The stream below can still deliver a later location update.
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) {
          _handlePosition(
            position,
            userId: userId,
            tripId: tripId,
            roomId: roomId,
          );
        });
  }

  void _joinRoom(String roomId) {
    _socket?.emit("join-room", roomId);
  }

  void _updateSnapshot(LocationSocketSnapshot snapshot) {
    _snapshot = snapshot;
    snapshotNotifier.value = snapshot;
  }

  Future<void> _startForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'AT Locator is running',
      notificationText: 'Keeping socket connected in background',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'stop', text: 'Stop'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );
  }

  Future<void> _stopForegroundTask() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }

  void _handleRemoteLocation(dynamic data) {
    try {
      if (data == null) return;

      Map<String, dynamic> json;

      if (data is String) {
        json = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        json = Map<String, dynamic>.from(data);
      } else {
        return;
      }

      final userId = int.tryParse(json['userId']?.toString() ?? '') ?? 0;
      if (userId <= 0) return;

      final lat = double.tryParse(json['latitude']?.toString() ?? '') ?? 0;
      final lng = double.tryParse(json['longitude']?.toString() ?? '') ?? 0;
      final speed = int.tryParse(json['speed']?.toString() ?? '') ?? 0;
      final heading = int.tryParse(json['heading']?.toString() ?? '') ?? 0;
      final accuracy = int.tryParse(json['accuracy']?.toString() ?? '') ?? 0;
      final recordedAt = DateTime.tryParse(json['recordedAt']?.toString() ?? '') ?? DateTime.now().toUtc();

      final member = MemberLocation(
        userId: userId,
        latitude: lat,
        longitude: lng,
        speedKmh: speed,
        heading: heading,
        accuracy: accuracy,
        recordedAt: recordedAt,
        displayName: json['name'] is String ? json['name'] as String : null,
      );

      final members = Map<int, MemberLocation>.from(_snapshot.members);
      members[userId] = member;

      _updateSnapshot(_snapshot.copyWith(members: members));
    } on Object catch (_) {
      // ignore parse errors
    }
  }

  void _handlePosition(
    Position position, {
    required int userId,
    required int tripId,
    required String roomId,
  }) {
    final telemetry = LocationTelemetry.fromPosition(position);
    final packets = [telemetry, ..._snapshot.recentPackets].take(5).toList();

    _updateSnapshot(
      _snapshot.copyWith(
        hasLocation: true,
        latestLocation: telemetry,
        recentPackets: packets,
      ),
    );

    if (!isConnected || tripId <= 0 || roomId.trim().isEmpty) return;

    _socket?.emit("location-update", {
      "userId": userId,
      "tripId": tripId,
      "roomId": roomId,
      "latitude": telemetry.latitude,
      "longitude": telemetry.longitude,
      "speed": telemetry.speedKmh,
      "heading": telemetry.heading,
      "accuracy": telemetry.accuracy,
      "recordedAt": telemetry.recordedAt.toIso8601String(),
    });
  }
}

@immutable
class MemberLocation {
  const MemberLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.accuracy,
    required this.recordedAt,
    this.displayName,
  });

  factory MemberLocation.fromMap(Map<String, dynamic> map) {
    final userId = int.tryParse(map['userId']?.toString() ?? '') ?? 0;
    return MemberLocation(
      userId: userId,
      latitude: double.tryParse(map['latitude']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(map['longitude']?.toString() ?? '') ?? 0,
      speedKmh: int.tryParse(map['speed']?.toString() ?? '') ?? 0,
      heading: int.tryParse(map['heading']?.toString() ?? '') ?? 0,
      accuracy: int.tryParse(map['accuracy']?.toString() ?? '') ?? 0,
      recordedAt: DateTime.tryParse(map['recordedAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
      displayName: map['name'] is String ? map['name'] as String : null,
    );
  }

  final int userId;
  final double latitude;
  final double longitude;
  final int speedKmh;
  final int heading;
  final int accuracy;
  final DateTime recordedAt;
  final String? displayName;
}

@immutable
class LocationSocketSnapshot {
  const LocationSocketSnapshot({
    required this.isStarted,
    required this.isConnected,
    required this.hasLocation,
    required this.userId,
    required this.tripId,
    required this.roomId,
    required this.latestLocation,
    required this.recentPackets,
    required this.members,
  });

  factory LocationSocketSnapshot.initial() {
    return const LocationSocketSnapshot(
      isStarted: false,
      isConnected: false,
      hasLocation: false,
      userId: null,
      tripId: 0,
      roomId: "",
      latestLocation: null,
      recentPackets: [],
      members: {},
    );
  }

  final bool isStarted;
  final bool isConnected;
  final bool hasLocation;
  final int? userId;
  final int tripId;
  final String roomId;
  final LocationTelemetry? latestLocation;
  final List<LocationTelemetry> recentPackets;
  final Map<int, MemberLocation> members;

  LocationSocketSnapshot copyWith({
    bool? isStarted,
    bool? isConnected,
    bool? hasLocation,
    int? userId,
    int? tripId,
    String? roomId,
    LocationTelemetry? latestLocation,
    List<LocationTelemetry>? recentPackets,
    Map<int, MemberLocation>? members,
  }) {
    return LocationSocketSnapshot(
      isStarted: isStarted ?? this.isStarted,
      isConnected: isConnected ?? this.isConnected,
      hasLocation: hasLocation ?? this.hasLocation,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      roomId: roomId ?? this.roomId,
      latestLocation: latestLocation ?? this.latestLocation,
      recentPackets: recentPackets ?? this.recentPackets,
      members: members ?? this.members,
    );
  }
}

@immutable
class LocationTelemetry {
  const LocationTelemetry({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.accuracy,
    required this.recordedAt,
  });

  factory LocationTelemetry.fromPosition(Position position) {
    return LocationTelemetry(
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: _speedInKmh(position.speed),
      heading: _finiteOrZero(position.heading).round(),
      accuracy: _finiteOrZero(position.accuracy).round(),
      recordedAt: DateTime.now().toUtc(),
    );
  }

  final double latitude;
  final double longitude;
  final int speedKmh;
  final int heading;
  final int accuracy;
  final DateTime recordedAt;

  static int _speedInKmh(double metersPerSecond) {
    final speed = _finiteOrZero(metersPerSecond);
    return (speed * 3.6).round();
  }

  static double _finiteOrZero(double value) {
    if (value.isFinite && value > 0) return value;
    return 0;
  }
}
