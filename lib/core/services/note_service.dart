import '../model/api_response.dart';
import 'chat_service.dart';

// =====================================================================
// FITUR: Layanan Catatan (API)
// FILE: lib/core/services/note_service.dart
// BARIS AWAL: 7 (setelah komentar ini)
// FUNGSI: Service khusus untuk mengelola Notes (Catatan) pada room/kontak. Mendelegasikan panggilan ke ChatService yang sudah teruji.
// =====================================================================
class NoteService {
  final ChatService _chatService = ChatService();

  /// Membuat atau memperbarui catatan pada ruang obrolan / kontak
  Future<ApiResponse<bool>> updateContactNotes(String contactId, String notes) {
    return _chatService.updateContactNotes(contactId, notes);
  }
}
