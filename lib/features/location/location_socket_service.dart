import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:atlocator/core/config/app_config.dart';
import 'package:atlocator/features/auth/session/auth_session.dart';

class LocationSocketService {
  LocationSocketService._();

  static final instance = LocationSocketService._();

  io.Socket? _socket;
  StreamSubscription<Position>? _positionSubscription;
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
    required int tripId,
    required String roomId,
  }) async {
    final resolvedUserId = userId ?? AuthSession.userId;
    if (resolvedUserId == null) return;
    if (tripId <= 0 || roomId.trim().isEmpty) return;

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
    _connectSocket(roomId);
    await _startLocationUpdates(
      userId: resolvedUserId,
      tripId: tripId,
      roomId: roomId,
    );
  }

  Future<void> stop() async {
    _started = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
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
        _joinRoom(roomId);
      })
      ..onConnectError((error) {
        debugPrint("Socket connection failed: $error");
        _updateSnapshot(_snapshot.copyWith(isConnected: false));
      })
      ..onError((error) {
        debugPrint("Socket runtime error: $error");
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

  void _handlePosition(
    Position position, {
    required int userId,
    required int tripId,
    required String roomId,
  }) {
    if (!_started || tripId <= 0 || roomId.trim().isEmpty) return;

    final telemetry = LocationTelemetry.fromPosition(position);
    final packets = [telemetry, ..._snapshot.recentPackets].take(5).toList();

    _updateSnapshot(
      _snapshot.copyWith(
        hasLocation: true,
        latestLocation: telemetry,
        recentPackets: packets,
      ),
    );

    if (!isConnected) return;

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

  LocationSocketSnapshot copyWith({
    bool? isStarted,
    bool? isConnected,
    bool? hasLocation,
    int? userId,
    int? tripId,
    String? roomId,
    LocationTelemetry? latestLocation,
    List<LocationTelemetry>? recentPackets,
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
