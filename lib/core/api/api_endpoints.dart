import 'package:atlocator/core/config/app_config.dart';

class ApiEndpoints {
  static const baseUrl = AppConfig.apiBaseUrl;

  static const login = "$baseUrl/api/auth/login";
}
