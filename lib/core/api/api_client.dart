import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlocator/features/auth/session/auth_session.dart';

import 'api_exception.dart';

class ApiClient {
  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    bool useAuthToken = true,
  }) async {
    final responseJson = await _send(
      method: "POST",
      url: url,
      body: body,
      useAuthToken: useAuthToken,
    );

    if (responseJson is Map<String, dynamic>) return responseJson;

    throw const FormatException("Expected a JSON object");
  }

  static Future<Map<String, dynamic>> getMap(
    String url, {
    bool useAuthToken = true,
  }) async {
    final responseJson = await _send(
      method: "GET",
      url: url,
      useAuthToken: useAuthToken,
    );

    if (responseJson is Map<String, dynamic>) return responseJson;

    throw const FormatException("Expected a JSON object");
  }

  static Future<List<dynamic>> getList(
    String url, {
    bool useAuthToken = true,
  }) async {
    final responseJson = await _send(
      method: "GET",
      url: url,
      useAuthToken: useAuthToken,
    );

    if (responseJson is List<dynamic>) return responseJson;
    if (responseJson is Map<String, dynamic>) {
      if (responseJson.isEmpty) return <dynamic>[];
      if (responseJson["data"] is List<dynamic>) {
        return responseJson["data"] as List<dynamic>;
      }
      if (responseJson["trips"] is List<dynamic>) {
        return responseJson["trips"] as List<dynamic>;
      }
      if (responseJson["items"] is List<dynamic>) {
        return responseJson["items"] as List<dynamic>;
      }
    }

    throw const FormatException("Expected a JSON array");
  }

  static Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
    bool useAuthToken = true,
  }) async {
    final responseJson = await _send(
      method: "PUT",
      url: url,
      body: body ?? <String, dynamic>{},
      useAuthToken: useAuthToken,
    );

    if (responseJson is Map<String, dynamic>) return responseJson;

    throw const FormatException("Expected a JSON object");
  }

  static Future<dynamic> _send({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    bool useAuthToken = true,
  }) async {
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException("Invalid API URL. Check AppConfig.apiBaseUrl.");
    }

    try {
      final headers = _headers(useAuthToken: useAuthToken);
      final encodedBody = body == null ? null : jsonEncode(body);
      final response = switch (method) {
        "GET" =>
          await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20)),
        "PUT" =>
          await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20)),
        _ =>
          await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20)),
      };

      final responseJson = _decodeResponse(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseJson;
      }

      throw ApiException(
        _errorMessageFor(response.statusCode, responseJson),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ApiException(
        "Request timed out. Please check your connection and try again.",
      );
    } on FormatException {
      throw const ApiException(
        "The server returned an invalid response. Please try again later.",
      );
    } on http.ClientException {
      throw const ApiException(
        "Could not connect to the server. Check your network or API URL.",
      );
    }
  }

  static Map<String, String> _headers({required bool useAuthToken}) {
    final headers = {"Content-Type": "application/json"};
    final token = AuthSession.token;

    if (useAuthToken && token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    return headers;
  }

  static dynamic _decodeResponse(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decodedBody = jsonDecode(body);

    if (decodedBody is Map<String, dynamic> || decodedBody is List<dynamic>) {
      return decodedBody;
    }

    throw const FormatException("Expected a JSON object or array");
  }

  static String _errorMessageFor(int statusCode, dynamic responseJson) {
    final serverMessage = responseJson is Map<String, dynamic>
        ? responseJson["message"]
        : null;

    if (serverMessage is String && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    switch (statusCode) {
      case 400:
        return "Please check the details you entered.";
      case 401:
        return "Invalid email or password.";
      case 403:
        return "You do not have permission to access this account.";
      case 404:
        return "The requested item was not found.";
      case 422:
        return "Some login details are invalid.";
      case >= 500:
        return "Server error. Please try again later.";
      default:
        return "Request failed. Please try again.";
    }
  }
}
