import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  late Dio _dio;
  String? _token;
  
  static const String baseUrl = 'https://id.nobox.ai/';

  static final ApiClient _instance = ApiClient._internal();
  Function? onUnauthorized;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging, auth, etc.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        debugPrint('ApiClient: ${options.method} ${options.path}');
        
        // Failsafe: load token from secure storage if not in memory
        if (_token == null) {
          const secureStorage = FlutterSecureStorage();
          _token = await secureStorage.read(key: 'auth_token');
          if (_token != null) {
            debugPrint('ApiClient: Token restored from secure storage');
          }
        }

        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        } else {
          debugPrint('ApiClient: No token found!');
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        final is401 = e.response?.statusCode == 401;
        final is400AccessDenied = e.response?.statusCode == 400 &&
            e.response?.data is Map &&
            e.response?.data['Error'] is Map &&
            e.response?.data['Error']['Code'] == 'AccessDenied';

        if (is401 || is400AccessDenied) {
          debugPrint('ApiClient: Unauthorized or Access Denied detected');
          // Prevent infinite loops by not logout if we are already trying to login/logout
          // or if the path is the token generation path
          if (!e.requestOptions.path.contains('AccountAPI/GenerateToken')) {
            onUnauthorized?.call();
          }
        }
        return handler.next(e);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  void setToken(String? token) {
    _token = token;
  }

  Dio get dio => _dio;

  // GET Request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response;
  }

  // POST Request
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.post(path, data: data, queryParameters: queryParameters);
    return response;
  }
}
