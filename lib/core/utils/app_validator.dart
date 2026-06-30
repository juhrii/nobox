// =====================================================================
// FITUR: Validasi Formulir
// FILE: lib/core/utils/app_validator.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Kumpulan fungsi pembantu (helper) untuk memvalidasi input teks dari pengguna, seperti format email dan panjang kata sandi.
// =====================================================================
class AppValidator {
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mohon masukkan email Anda';
    }
    if (!_emailRegex.hasMatch(value)) {
      return 'Mohon masukkan format email yang valid';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mohon masukkan kata sandi Anda';
    }
    if (value.length < 8) {
      return 'Kata sandi minimal harus 8 karakter';
    }
    return null;
  }
}
