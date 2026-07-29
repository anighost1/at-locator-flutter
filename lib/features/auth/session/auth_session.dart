class AuthSession {
  AuthSession._();

  static String? _token;

  static String? get token => _token;

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static void saveToken(String token) {
    _token = token;
  }

  static void clear() {
    _token = null;
  }
}
