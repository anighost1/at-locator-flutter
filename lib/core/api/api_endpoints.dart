import 'package:atlocator/core/config/app_config.dart';

class ApiEndpoints {
  static const baseUrl = AppConfig.apiBaseUrl;

  static const login = "$baseUrl/api/auth/login";
  static const trips = "$baseUrl/api/trip";
  static const createTrip = "$baseUrl/api/trip";
  static const ongoingTrip = "$baseUrl/api/trip/ongoing";

  static String endTrip(int tripId) => "$baseUrl/api/trip/end/$tripId";

  static String tripSummary(int tripId) => "$baseUrl/api/trip/summary/$tripId";
}
