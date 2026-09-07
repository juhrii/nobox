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
  static const String _dateFormatKey = 'chat_date_format';
  static const String _timeFormatKey = 'chat_time_format';

  String _dateFormat = 'dd/MM/yyyy'; // Default
  String _timeFormat = 'HH:mm'; // Default

  Color? get backgroundColor => _backgroundColor;
  String? get backgroundImagePath => _backgroundImagePath;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;

  // FITUR: Muat Pengaturan
  /// Memuat pengaturan yang tersimpan dari SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final colorValue = prefs.getInt(_bgColorKey);
    if (colorValue != null) {
      _backgroundColor = Color(colorValue);
    }

    _backgroundImagePath = prefs.getString(_bgImageKey);
    _dateFormat = prefs.getString(_dateFormatKey) ?? 'dd/MM/yyyy';
    _timeFormat = prefs.getString(_timeFormatKey) ?? 'HH:mm';
    notifyListeners();
  }

  void setDateTimeFormat(String dateFormat, String timeFormat) {
    _dateFormat = dateFormat;
    _timeFormat = timeFormat;
    _saveSettings();
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

    await prefs.setString(_dateFormatKey, _dateFormat);
    await prefs.setString(_timeFormatKey, _timeFormat);
  }
}
