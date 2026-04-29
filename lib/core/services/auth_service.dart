import 'package:dio/dio.dart';
import 'api_client.dart';
import '../app_config.dart';
import '../model/api_response.dart';
import '../model/login_request.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<ApiResponse<String>> login(LoginRequest request) async {
    try {
      final response = await _apiClient.post(
        AppConfig.generateTokenEndpoint,
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          _apiClient.setToken(token);
          return ApiResponse.success(token, response.statusCode!);
        } else {
          return ApiResponse.failure(
            response.data['error'] ?? 'Login failed: Token not found',
            response.statusCode!,
          );
        }
      } else {
        return ApiResponse.failure(
          'Login failed with status: ${response.statusCode}',
          response.statusCode!,
        );
      }
    } on DioException catch (e) {
      String errorMessage = e.message ?? 'Unknown connection error';
      if (e.response != null && e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      return ApiResponse.failure(errorMessage, e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }
}
