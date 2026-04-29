import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../model/api_response.dart';
import '../model/login_request.dart';
import '../services/api_client.dart';
import '../utils/globals.dart';
import '../utils/app_routes.dart';

class AuthProvider with ChangeNotifier {
  String? _currentUser;
  bool _isLoading = true;
  bool _isAuthenticating = false;

  final AuthService _authService = AuthService();
  String? _token;

  // Secure storage for sensitive data (tokens)
  static const _secureStorage = FlutterSecureStorage();
  static const String _secureTokenKey = 'auth_token';

  AuthProvider() {
    ApiClient().onUnauthorized = logout;
  }

  // SharedPreferences keys (non-sensitive data only)
  static const String _userEmailKey = 'user_email';
  static const String _rememberEmailKey = 'remembered_email';

  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticating => _isAuthenticating;

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString(_userEmailKey);
    
    // Read token from secure storage
    _token = await _secureStorage.read(key: _secureTokenKey);
    
    // Auto-migrate token if it exists in SharedPreferences but not in secure storage
    if (_token == null) {
      final oldToken = prefs.getString(_secureTokenKey); // previously used same key
      if (oldToken != null) {
        // Migrate to secure storage
        await _secureStorage.write(key: _secureTokenKey, value: oldToken);
        // Remove from SharedPreferences for security
        await prefs.remove(_secureTokenKey);
        _token = oldToken;
        debugPrint('AuthProvider: Migrated token from SharedPreferences to Secure Storage');
      }
    }
    
    // If we STILL don't have a token, mark user as logged out
    if (_token == null) {
      _currentUser = null;
    }

    // Restore token in AuthService/ApiClient if it exists
    if (_token != null) {
      ApiClient().setToken(_token);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberEmailKey);
  }

  Future<void> saveRememberedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email != null) {
      await prefs.setString(_rememberEmailKey, email);
    } else {
      await prefs.remove(_rememberEmailKey);
    }
  }

  Future<ApiResponse<String>> login(String email, String password) async {
    _isAuthenticating = true;
    notifyListeners();

    try {
      final response = await _authService.login(
        LoginRequest(username: email, password: password),
      );

      if (!response.isError && response.data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userEmailKey, email);
        
        // Store token in secure storage instead of SharedPreferences
        await _secureStorage.write(key: _secureTokenKey, value: response.data!);
        
        _currentUser = email;
        _token = response.data;
        
        _isAuthenticating = false;
        notifyListeners();
        return response;
      }
      
      _isAuthenticating = false;
      notifyListeners();
      return response;
    } catch (e) {
      debugPrint('AuthProvider Login Error: $e');
      _isAuthenticating = false;
      notifyListeners();
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  void logout() async {
    // Guard: if already logged out, don't re-run logout logic.
    // This prevents repeated background 401/AccessDenied responses from
    // re-pushing the login page and clearing the user's typed credentials.
    if (_currentUser == null && _token == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_rememberEmailKey, _currentUser!);
    }
    await prefs.remove(_userEmailKey);
    
    // Delete token from secure storage
    await _secureStorage.delete(key: _secureTokenKey);
    
    _currentUser = null;
    _token = null;
    ApiClient().setToken(null);
    notifyListeners();

    // Navigate to login screen automatically
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }
}
