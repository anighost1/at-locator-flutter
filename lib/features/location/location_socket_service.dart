import 'dart:async';

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

  bool get isStarted => _started;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> start({
    int? userId,
    int tripId = AppConfig.activeTripId,
    String roomId = AppConfig.activeTripRoomId,
  }) async {
    if (_started) return;

    final resolvedUserId = userId ?? AuthSession.userId;
    if (resolvedUserId == null) return;

    _started = true;
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
  }

  void _connectSocket(String roomId) {
    final token = AuthSession.token;

    final options = io.OptionBuilder()
        .setTransports(["websocket"])
        .disableAutoConnect()
        .setAuth({
          if (token != null && token.isNotEmpty) "token": token,
        })
        .build();

    _socket = io.io(AppConfig.apiBaseUrl, options);
    _socket
      ?..onConnect((_) => _joinRoom(roomId))
      ..onReconnect((_) => _joinRoom(roomId))
      ..connect();
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

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        if (!_started || !isConnected) return;

        _socket?.emit("location-update", {
          "userId": userId,
          "tripId": tripId,
          "roomId": roomId,
          "latitude": position.latitude,
          "longitude": position.longitude,
          "speed": _speedInKmh(position.speed),
          "heading": _finiteOrZero(position.heading).round(),
          "accuracy": _finiteOrZero(position.accuracy).round(),
          "recordedAt": DateTime.now().toUtc().toIso8601String(),
        });
      },
    );
  }

  void _joinRoom(String roomId) {
    _socket?.emit("join-room", roomId);
  }

  int _speedInKmh(double metersPerSecond) {
    final speed = _finiteOrZero(metersPerSecond);
    return (speed * 3.6).round();
  }

  double _finiteOrZero(double value) {
    if (value.isFinite && value > 0) return value;
    return 0;
  }
}
