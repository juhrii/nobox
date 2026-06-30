import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// FITUR: Provider Pengaturan Chat
// FILE: lib/core/providers/chat_settings_provider.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Mengelola pengaturan tampilan chat, seperti background warna atau gambar
// =====================================================================
class ChatSettingsProvider with ChangeNotifier {
  Color? _backgroundColor;
  String? _backgroundImagePath;
  
  static const String _bgColorKey = 'chat_bg_color';
  static const String _bgImageKey = 'chat_bg_image';

  Color? get backgroundColor => _backgroundColor;
  String? get backgroundImagePath => _backgroundImagePath;

  // FITUR: Muat Pengaturan
  /// Memuat pengaturan yang tersimpan dari SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final colorValue = prefs.getInt(_bgColorKey);
    if (colorValue != null) {
      _backgroundColor = Color(colorValue);
    }

    _backgroundImagePath = prefs.getString(_bgImageKey);
    notifyListeners();
  }

  void setBackgroundColor(Color? color) {
    _backgroundColor = color;
    _backgroundImagePath = null; // hapus gambar jika warna diatur
    _saveSettings();
    notifyListeners();
  }

  void setBackgroundImage(String? path) {
    _backgroundImagePath = path;
    _backgroundColor = null; // hapus warna jika gambar diatur
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_backgroundColor != null) {
      await prefs.setInt(_bgColorKey, _backgroundColor!.value);
    } else {
      await prefs.remove(_bgColorKey);
    }

    if (_backgroundImagePath != null) {
      await prefs.setString(_bgImageKey, _backgroundImagePath!);
    } else {
      await prefs.remove(_bgImageKey);
    }
  }
}
