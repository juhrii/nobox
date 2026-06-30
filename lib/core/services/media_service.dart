import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../app_config.dart';

// =====================================================================
// FITUR: Layanan Media (API)
// FILE: lib/core/services/media_service.dart
// BARIS AWAL: 7 (setelah komentar ini)
// FUNGSI: Mengelola pengunggahan (upload) file media ke server (gambar, dokumen, suara, dll)
// =====================================================================
class MediaService {
  final ApiClient _apiClient = ApiClient();

  /// Mengunggah media ke server menggunakan format string Base64.
  /// Mengembalikan nama file yang diunggah di server jika berhasil, atau null jika gagal.
  Future<String?> uploadMedia({
    required String filename,
    required String mimetype,
    required String base64Data,
  }) async {
    try {
      debugPrint('MediaService: ┌── Uploading Media ──');
      debugPrint('MediaService: │ Endpoint: ${AppConfig.uploadBase64Endpoint}');
      debugPrint('MediaService: │ Filename: $filename');
      debugPrint('MediaService: │ Mimetype: $mimetype');
      
      final payload = {
        "media": {
          "filename": filename,
          "mimetype": mimetype,
          "data": base64Data,
        },
      };

      final response = await _apiClient.post(
        AppConfig.uploadBase64Endpoint,
        data: payload,
      );

      debugPrint('MediaService: │ Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final rawData = response.data;
        if (rawData is Map && rawData['IsError'] == false && rawData['Data'] != null) {
          final serverFilename = rawData['Data']['Filename']?.toString() ?? rawData['Data']['FileName']?.toString() ?? rawData['Data']['filename']?.toString();
          debugPrint('MediaService: │ ✅ Upload Success! Server Filename: $serverFilename');
          debugPrint('MediaService: └──────────────────────');
          return serverFilename;
        } else {
          final errorMsg = rawData['Error']?.toString() ?? 'Upload failed';
          debugPrint('MediaService: │ ❌ Server Error: $errorMsg');
          debugPrint('MediaService: └──────────────────────');
          return null;
        }
      } else {
        debugPrint('MediaService: │ ❌ HTTP ${response.statusCode}');
        debugPrint('MediaService: └──────────────────────');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('MediaService: uploadMedia DioException: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('MediaService: uploadMedia error: $e');
      return null;
    }
  }
}
