import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final decodedBody = jsonDecode(response.body);
    final responseJson = decodedBody is Map<String, dynamic>
        ? decodedBody
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseJson;
    }

    throw Exception(responseJson["message"] ?? "Something went wrong");
  }
}
