import '../model/api_response.dart';
import 'chat_service.dart';

/// Service khusus untuk mengelola Notes (Catatan) pada room.
/// Mendelegasikan panggilan ke ChatService yang sudah teruji.
class NoteService {
  final ChatService _chatService = ChatService();

  /// Create or update a note on a room/contact
  Future<ApiResponse<bool>> updateContactNotes(String contactId, String notes) {
    return _chatService.updateContactNotes(contactId, notes);
  }
}
