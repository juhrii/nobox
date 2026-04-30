import '../model/api_response.dart';
import 'chat_service.dart';

/// Service khusus untuk mengelola Tags pada room.
/// Mendelegasikan panggilan ke ChatService yang sudah teruji.
class TagService {
  final ChatService _chatService = ChatService();

  /// Update Room Tags (replace all tags)
  Future<ApiResponse<bool>> updateContactTags(String contactId, List<String> tags) {
    return _chatService.updateContactTags(contactId, tags);
  }

  /// Add a single tag to a room
  Future<ApiResponse<bool>> addTagToRoom(String roomId, String tagId) {
    return _chatService.addTagToRoom(roomId, tagId);
  }

  /// Remove a single tag from a room
  Future<ApiResponse<bool>> removeTagFromRoom(String roomId, String tagId) {
    return _chatService.removeTagFromRoom(roomId, tagId);
  }

  /// Fetch list of all available Tags
  Future<ApiResponse<List<Map<String, dynamic>>>> getTags() {
    return _chatService.getTags();
  }
}
