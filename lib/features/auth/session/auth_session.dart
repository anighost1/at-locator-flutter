import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSession {
  AuthSession._();

  static const _tokenKey = "auth_token";
  static const _storageTimeout = Duration(seconds: 2);
  static const _storage = FlutterSecureStorage();

  static String? _token;

  static String? get token => _token;

  static int? get userId {
    final payload = _tokenPayload;
    final value = payload?["userId"];

    if (value is int) return value;
    if (value is String) return int.tryParse(value);

    return null;
  }

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Future<void> load() async {
    try {
      _token = await _storage
          .read(key: _tokenKey)
          .timeout(_storageTimeout);
    } on Object {
      _token = null;
    }
  }

  static Future<void> saveToken(String token) async {
    _token = token;

    try {
      await _storage
          .write(key: _tokenKey, value: token)
          .timeout(_storageTimeout);
    } on Object {
      // Keep the in-memory token so the current app session can continue.
    }
  }

  static Future<void> clear() async {
    _token = null;

    try {
      await _storage.delete(key: _tokenKey).timeout(_storageTimeout);
    } on Object {
      // The local session is already cleared; storage can be retried later.
    }
  }

  static Map<String, dynamic>? get _tokenPayload {
    final token = _token;

    if (token == null || token.isEmpty) return null;

    final parts = token.split(".");
    if (parts.length != 3) return null;

    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decodedPayload = jsonDecode(payload);

      if (decodedPayload is Map<String, dynamic>) {
        return decodedPayload;
      }
    } on Object {
      return null;
    }

    return null;
  }
}
