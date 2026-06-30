// =====================================================================
// FITUR: Layanan Manajemen Cache Gambar
// FILE: lib/core/services/image_cache_manager.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Mengelola penyimpanan (cache) gambar lokal untuk mempercepat pemuatan dan menghemat data internet
// =====================================================================
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager {
  static const key = 'customImageCacheKey';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // Simpan cache gambar selama 7 hari
      maxNrOfCacheObjects: 200, // Jumlah maksimum gambar yang disimpan di cache
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  // FITUR: Hapus Semua Cache Gambar
  /// Menghapus semua gambar yang tersimpan di cache
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
