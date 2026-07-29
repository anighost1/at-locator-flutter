import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

import '../models/login_request.dart';
import '../models/login_response.dart';

class AuthRepository {
  Future<LoginResponse> login(LoginRequest request) async {
    final json = await ApiClient.post(ApiEndpoints.login, request.toJson());

    return LoginResponse.fromJson(json);
  }
}
