// =====================================================================
// FITUR: Model Request Login
// FILE: lib/core/model/login_request.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class model untuk membungkus data username dan password saat login
// =====================================================================
class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  // FITUR: Convert ke JSON
  // FUNGSI: Mengubah objek LoginRequest menjadi format JSON (Map) untuk dikirim ke API
  Map<String, dynamic> toJson() {
    return {
      'userName': username,
      'password': password,
    };
  }
}
