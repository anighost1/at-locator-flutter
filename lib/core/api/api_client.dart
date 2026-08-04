import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlocator/features/auth/session/auth_session.dart';

import 'api_exception.dart';

class ApiClient {
  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
    {bool useAuthToken = true}
  ) async {
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException("Invalid API URL. Check AppConfig.apiBaseUrl.");
    }

    try {
      final response = await http
          .post(
            uri,
            headers: _headers(useAuthToken: useAuthToken),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

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

  static Map<String, dynamic> _decodeResponse(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decodedBody = jsonDecode(body);

    if (decodedBody is Map<String, dynamic>) {
      return decodedBody;
    }

    throw const FormatException("Expected a JSON object");
  }

  static String _errorMessageFor(
    int statusCode,
    Map<String, dynamic> responseJson,
  ) {
    final serverMessage = responseJson["message"];

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
        return "Login service was not found. Check the API endpoint.";
      case 422:
        return "Some login details are invalid.";
      case >= 500:
        return "Server error. Please try again later.";
      default:
        return "Request failed. Please try again.";
    }
  }
}
