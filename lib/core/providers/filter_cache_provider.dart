import 'package:flutter/foundation.dart';

// =====================================================================
// FITUR: Provider Cache Filter
// FILE: lib/core/providers/filter_cache_provider.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menyimpan sementara (cache) data list tag, funnel, channel, dan akun untuk filter
// =====================================================================
class FilterCacheProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _funnels = [];
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _accounts = [];
  
  bool _isDataLoaded = false;
  
  // Getter (pengambil data)
  List<Map<String, dynamic>> get tags => _tags;
  List<Map<String, dynamic>> get funnels => _funnels;
  List<Map<String, dynamic>> get channels => _channels;
  List<Map<String, dynamic>> get accounts => _accounts;
  bool get isDataLoaded => _isDataLoaded;

  // FITUR: Perbarui Data Filter
  /// Memperbarui semua data filter secara bersamaan dan memberitahu UI
  void updateFilterData({
    required List<Map<String, dynamic>> tags,
    required List<Map<String, dynamic>> funnels,
    required List<Map<String, dynamic>> channels,
    required List<Map<String, dynamic>> accounts,
  }) {
    _tags = tags;
    _funnels = funnels;
    _channels = channels;
    _accounts = accounts;
    _isDataLoaded = true;
    notifyListeners();
  }

  // FITUR: Hapus Cache
  /// Mengosongkan/menghapus data cache filter
  void invalidateCache() {
    _tags = [];
    _funnels = [];
    _channels = [];
    _accounts = [];
    _isDataLoaded = false;
    notifyListeners();
  }
}
