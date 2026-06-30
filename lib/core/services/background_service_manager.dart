import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_config.dart';

// =====================================================================
// FITUR: Pengelola Layanan Latar Belakang (Background Service)
// FILE: lib/core/services/background_service_manager.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Mengelola Background Service native Android untuk menjaga koneksi SignalR
//         tetap hidup saat aplikasi di-minimize. Berkomunikasi dengan SignalRBackgroundService.kt via MethodChannel.
// =====================================================================
class BackgroundServiceManager {
  static const _channel = MethodChannel('ai.nobox.android/background_service');
  static bool _isRunning = false;

  /// Memulai background service dengan token JWT terbaru.
  /// Dipanggil saat aplikasi masuk ke background (paused/hidden).
  static Future<void> startService() async {
    if (_isRunning) return;

    try {
      // Ambil token terbaru dari secure storage
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConfig.tokenKey);

      if (token == null || token.isEmpty) {
        debugPrint('BackgroundServiceManager: No token found, skipping start.');
        return;
      }

      await _channel.invokeMethod('startBackgroundService', {'token': token});
      _isRunning = true;
      debugPrint('BackgroundServiceManager: ✅ Background service started.');
    } on PlatformException catch (e) {
      debugPrint('BackgroundServiceManager: ❌ PlatformException: ${e.message}');
    } on MissingPluginException {
      debugPrint('BackgroundServiceManager: ⚠️ MethodChannel not available (not on Android?).');
    } catch (e) {
      debugPrint('BackgroundServiceManager: ❌ Error starting service: $e');
    }
  }

  /// Menghentikan background service.
  /// Dipanggil saat aplikasi kembali ke foreground (resumed).
  static Future<void> stopService() async {
    if (!_isRunning) return;

    try {
      await _channel.invokeMethod('stopBackgroundService');
      _isRunning = false;
      debugPrint('BackgroundServiceManager: 🛑 Background service stopped.');
    } on PlatformException catch (e) {
      debugPrint('BackgroundServiceManager: ❌ PlatformException: ${e.message}');
    } on MissingPluginException {
      debugPrint('BackgroundServiceManager: ⚠️ MethodChannel not available.');
    } catch (e) {
      debugPrint('BackgroundServiceManager: ❌ Error stopping service: $e');
    }
  }

  /// Cek apakah service sedang berjalan
  static bool get isRunning => _isRunning;
}
