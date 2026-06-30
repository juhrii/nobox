import '../model/api_response.dart';
import 'chat_service.dart';

// =====================================================================
// FITUR: Layanan Tag (API)
// FILE: lib/core/services/tag_service.dart
// BARIS AWAL: 7 (setelah komentar ini)
// FUNGSI: Service khusus untuk mengelola Tags (Label) pada room. Mendelegasikan panggilan ke ChatService yang sudah teruji.
// =====================================================================
class TagService {
  final ChatService _chatService = ChatService();

  /// Memperbarui Tags Room (mengganti semua tag yang ada)
  Future<ApiResponse<bool>> updateContactTags(String contactId, List<String> tags) {
    return _chatService.updateContactTags(contactId, tags);
  }

  /// Menambahkan satu tag ke dalam room
  Future<ApiResponse<bool>> addTagToRoom(String roomId, String tagId) {
    return _chatService.addTagToRoom(roomId, tagId);
  }

  /// Menghapus satu tag dari room
  Future<ApiResponse<bool>> removeTagFromRoom(String roomId, String tagId) {
    return _chatService.removeTagFromRoom(roomId, tagId);
  }

  /// Mengambil daftar semua Tags yang tersedia
  Future<ApiResponse<List<Map<String, dynamic>>>> getTags() {
    return _chatService.getTags();
  }
}
