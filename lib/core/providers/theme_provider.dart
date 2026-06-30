import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// FITUR: Provider Tema Aplikasi
// FILE: lib/core/providers/theme_provider.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Mengelola tema aplikasi (Mode Terang/Gelap) dan penyimpanannya
// =====================================================================
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeKey = 'is_dark_mode';

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey);
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isOn);
  }
}
