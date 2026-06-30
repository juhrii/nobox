// =====================================================================
// FITUR: Layanan Cache Agen
// FILE: lib/core/services/agent_cache_service.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menyimpan daftar agen (human agent) secara lokal di memori untuk mengurangi request API
// =====================================================================
class AgentCacheService {
  static final AgentCacheService _instance = AgentCacheService._internal();
  factory AgentCacheService() => _instance;
  AgentCacheService._internal();

  List<Map<String, dynamic>>? _cachedAgents;
  DateTime? _lastFetchTime;
  
  // Cache kedaluwarsa setelah 15 menit untuk mencegah penyimpanan data usang
  static const _cacheDuration = Duration(minutes: 15);

  // FITUR: Ambil Data Cache
  /// Mengembalikan agen yang tersimpan di cache jika tersedia dan masih valid, jika tidak kembalikan null
  List<Map<String, dynamic>>? get cachedAgents {
    if (_cachedAgents != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        return _cachedAgents;
      }
    }
    return null;
  }

  // FITUR: Perbarui Cache
  /// Memperbarui cache dengan data agen terbaru
  void updateCache(List<Map<String, dynamic>> agents) {
    _cachedAgents = agents;
    _lastFetchTime = DateTime.now();
  }

  // FITUR: Hapus Cache
  /// Mengosongkan seluruh data cache agen
  void invalidateCache() {
    _cachedAgents = null;
    _lastFetchTime = null;
  }
}
