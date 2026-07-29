class LoginResponse {
  final String token;

  LoginResponse({required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json["token"];

    if (token is! String || token.isEmpty) {
      throw const FormatException("Login response is missing token");
    }

    return LoginResponse(token: token);
  }
}
