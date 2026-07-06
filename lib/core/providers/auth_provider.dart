// =====================================================================
// FITUR 1: Autentikasi Pengguna (Auth Provider)
// TUJUAN: Mengelola state login pengguna, menyimpan token JWT, dan memvalidasi kredensial.
// =====================================================================
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../model/api_response.dart';
import '../model/login_request.dart';
import '../services/api_client.dart';
import '../app_config.dart';
import '../utils/globals.dart';
import '../utils/app_routes.dart';

// =====================================================================
// FITUR: Provider Autentikasi
// FILE: lib/core/providers/auth_provider.dart
// BARIS AWAL: 13 (setelah komentar ini)
// FUNGSI: Mengelola state login, logout, penyimpanan token, dan sesi pengguna
// =====================================================================
class AuthProvider with ChangeNotifier {
  String? _currentUser;
  bool _isLoading = true;
  bool _isAuthenticating = false;

  final AuthService _authService = AuthService();
  String? _token;

  // Penyimpanan aman (Secure storage) untuk data sensitif (seperti token)
  static const _secureStorage = FlutterSecureStorage();
  static const String _secureTokenKey = 'auth_token';

  AuthProvider() {
    ApiClient().onUnauthorized = logout;
  }

  // Kunci SharedPreferences (hanya untuk data yang tidak sensitif)
  static const String _userEmailKey = 'user_email';
  static const String _rememberEmailKey = 'remembered_email';

  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticating => _isAuthenticating;

  // FITUR: Cek Status Autentikasi
  // FUNGSI: Memeriksa apakah user sudah login atau belum saat aplikasi pertama dibuka
  // [ACTION: AUTH_CHECK] - Memeriksa token saat aplikasi pertama kali dibuka
  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString(_userEmailKey);
    
    // Baca token dari secure storage
    _token = await _secureStorage.read(key: _secureTokenKey);
    
    // Migrasi token otomatis jika ada di SharedPreferences tetapi tidak di secure storage
    if (_token == null) {
      final oldToken = prefs.getString(_secureTokenKey); // sebelumnya menggunakan kunci yang sama
      if (oldToken != null) {
        // Migrasi ke secure storage
        await _secureStorage.write(key: _secureTokenKey, value: oldToken);
        // Hapus dari SharedPreferences demi keamanan
        await prefs.remove(_secureTokenKey);
        _token = oldToken;
        debugPrint('AuthProvider: Migrated token from SharedPreferences to Secure Storage');
      }
    }
    
    // Jika tidak ada token tapi ada saved credentials → silent re-login
    if (_token == null) {
      final savedUsername = await _secureStorage.read(key: AppConfig.lastUsernameKey);
      final savedPassword = await _secureStorage.read(key: AppConfig.lastPasswordKey);
      if (savedUsername != null && savedPassword != null) {
        debugPrint('AuthProvider: No token but credentials found, attempting silent re-login...');
        final result = await tryAutoReLogin();
        if (result) {
          debugPrint('AuthProvider: ✅ Silent re-login successful in checkAuth');
        } else {
          debugPrint('AuthProvider: ❌ Silent re-login failed in checkAuth');
          _currentUser = null;
        }
      } else {
        _currentUser = null;
      }
    }

    // Pulihkan token di AuthService/ApiClient jika ada
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

  // FITUR: Login
  // FUNGSI: Memproses permintaan login dari user ke API
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
        
        // Simpan token di secure storage, bukan di SharedPreferences
        await _secureStorage.write(key: _secureTokenKey, value: response.data!);
        
        // Simpan credentials untuk auto re-login saat token expired
        await _secureStorage.write(key: AppConfig.lastUsernameKey, value: email);
        await _secureStorage.write(key: AppConfig.lastPasswordKey, value: password);
        debugPrint('AuthProvider: ✅ Credentials saved for auto re-login');
        
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

  // FITUR: Auto Re-Login (Silent)
  /// Silent re-login menggunakan saved credentials.
  /// Dipanggil dari splash_page, chat_detail, atau interceptor.
  /// Return true jika berhasil, false jika gagal.
  Future<bool> tryAutoReLogin() async {
    try {
      final savedUsername = await _secureStorage.read(key: AppConfig.lastUsernameKey);
      final savedPassword = await _secureStorage.read(key: AppConfig.lastPasswordKey);

      if (savedUsername == null || savedPassword == null) {
        debugPrint('AuthProvider: tryAutoReLogin - No saved credentials');
        return false;
      }

      debugPrint('AuthProvider: 🔑 tryAutoReLogin for $savedUsername...');

      final response = await _authService.login(
        LoginRequest(username: savedUsername, password: savedPassword),
      );

      if (!response.isError && response.data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userEmailKey, savedUsername);
        await _secureStorage.write(key: _secureTokenKey, value: response.data!);

        _currentUser = savedUsername;
        _token = response.data;
        ApiClient().setToken(_token);

        notifyListeners();
        debugPrint('AuthProvider: ✅ tryAutoReLogin successful');
        return true;
      }

      debugPrint('AuthProvider: ❌ tryAutoReLogin failed: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('AuthProvider: ❌ tryAutoReLogin error: $e');
      return false;
    }
  }

  // FITUR: Logout
  // FUNGSI: Menghapus sesi, menghapus token, dan mengarahkan kembali ke halaman login
  // [ACTION: LOGOUT_EXECUTE] - Menghapus sesi, menghapus token, dan mengarahkan kembali ke halaman login
  void logout() async {
    // Guard: jika sudah logout, jangan jalankan ulang logika logout.
    // Ini mencegah respons 401/AccessDenied dari background process agar
    // tidak berulang kali mendorong halaman login dan menghapus teks input pengguna.
    if (_currentUser == null && _token == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_rememberEmailKey, _currentUser!);
    }
    await prefs.remove(_userEmailKey);
    
    // Hapus token dari secure storage
    await _secureStorage.delete(key: _secureTokenKey);
    
    // JANGAN hapus last_username & last_password saat logout
    // agar user bisa auto re-login saat buka app lagi
    // (credentials dihapus hanya jika user ganti akun)
    
    _currentUser = null;
    _token = null;
    ApiClient().setToken(null);
    notifyListeners();

    // Arahkan kembali ke layar login secara otomatis
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }
}
