import 'package:flutter/foundation.dart';

// =====================================================================
// FITUR: Provider Cache Percakapan Baru
// FILE: lib/core/providers/new_conversation_cache_provider.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menyimpan sementara (cache) data kontak, grup, channel, dll untuk membuat percakapan baru
// =====================================================================
class NewConversationCacheProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _campaigns = [];
  
  bool _isDataLoaded = false;
  
  // Getter (pengambil data)
  List<Map<String, dynamic>> get contacts => _contacts;
  List<Map<String, dynamic>> get groups => _groups;
  List<Map<String, dynamic>> get channels => _channels;
  List<Map<String, dynamic>> get accounts => _accounts;
  List<Map<String, dynamic>> get links => _links;
  List<Map<String, dynamic>> get campaigns => _campaigns;
  bool get isDataLoaded => _isDataLoaded;

  // FITUR: Perbarui Data Percakapan
  /// Memperbarui semua data setup percakapan sekaligus dan memberitahu UI
  void updateConversationData({
    required List<Map<String, dynamic>> contacts,
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> channels,
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> links,
    required List<Map<String, dynamic>> campaigns,
  }) {
    _contacts = contacts;
    _groups = groups;
    _channels = channels;
    _accounts = accounts;
    _links = links;
    _campaigns = campaigns;
    _isDataLoaded = true;
    notifyListeners();
  }

  // FITUR: Hapus Cache
  /// Mengosongkan/menghapus data cache percakapan baru
  void invalidateCache() {
    _contacts = [];
    _groups = [];
    _channels = [];
    _accounts = [];
    _links = [];
    _campaigns = [];
    _isDataLoaded = false;
    notifyListeners();
  }
}
