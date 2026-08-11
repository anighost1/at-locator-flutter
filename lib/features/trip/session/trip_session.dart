import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:atlocator/features/trip/models/trip_models.dart';

class TripSession {
  TripSession._();

  static const _tripIdKey = "active_trip_id";
  static const _tripCodeKey = "active_trip_code";
  static const _tripNameKey = "active_trip_name";
  static const _storageTimeout = Duration(seconds: 2);
  static const _storage = FlutterSecureStorage();

  static int? _tripId;
  static String? _tripCode;
  static String? _tripName;

  static int? get tripId => _tripId;
  static String? get tripCode => _tripCode;
  static String? get tripName => _tripName;

  static Future<void> load() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _tripIdKey),
        _storage.read(key: _tripCodeKey),
        _storage.read(key: _tripNameKey),
      ]).timeout(_storageTimeout);

      _tripId = int.tryParse(values[0] ?? "");
      _tripCode = values[1];
      _tripName = values[2];
    } on Object {
      _tripId = null;
      _tripCode = null;
      _tripName = null;
    }
  }

  static Future<void> save(Trip trip) async {
    _tripId = trip.id;
    _tripCode = trip.tripCode;
    _tripName = trip.name;

    try {
      await Future.wait([
        _storage.write(key: _tripIdKey, value: trip.id.toString()),
        _storage.write(key: _tripCodeKey, value: trip.tripCode),
        _storage.write(key: _tripNameKey, value: trip.name),
      ]).timeout(_storageTimeout);
    } on Object {
      // Keep the in-memory trip data so this session can continue.
    }
  }

  static Future<void> clear() async {
    _tripId = null;
    _tripCode = null;
    _tripName = null;

    try {
      await Future.wait([
        _storage.delete(key: _tripIdKey),
        _storage.delete(key: _tripCodeKey),
        _storage.delete(key: _tripNameKey),
      ]).timeout(_storageTimeout);
    } on Object {
      // The local session is already cleared; storage can be retried later.
    }
  }
}
