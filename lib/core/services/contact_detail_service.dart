import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../app_config.dart';
import '../model/api_response.dart';
import 'chat_service.dart';

/// Service khusus untuk mengelola detail kontak/room.
/// Mendelegasikan panggilan ke ChatService yang sudah teruji.
class ContactDetailService {
  final ChatService _chatService = ChatService();

  /// Fetch full room detail (Tags, Funnel, Campaign, Deal, Notes, etc.)
  Future<ApiResponse<Map<String, dynamic>>> getDetailRoom(String roomId) {
    return _chatService.getDetailRoom(roomId);
  }

  /// Update Contact Info — splits into Chatrooms/Update and Contact/Update
  Future<ApiResponse<bool>> updateContactInfo(String contactId, Map<String, dynamic> contactData) {
    return _chatService.updateContactInfo(contactId, contactData);
  }

  /// Get archived room detail
  Future<ApiResponse<Map<String, dynamic>>> getArchivedRoomDetail(String roomId) {
    return _chatService.getArchivedRoomDetail(roomId);
  }

  /// Toggle AI Agent Mute Status
  Future<ApiResponse<bool>> toggleAiAgent(String contactId, bool isMuted) {
    return _chatService.toggleAiAgent(contactId, isMuted);
  }

  /// Toggle Need Reply Status
  Future<ApiResponse<bool>> toggleNeedReply(String contactId, bool needReply) {
    return _chatService.toggleNeedReply(contactId, needReply);
  }

  /// Assign Chat to Current User
  Future<ApiResponse<bool>> assignChat(String contactId) {
    return _chatService.assignChat(contactId);
  }

  /// Resolve / Close Chat
  Future<ApiResponse<bool>> resolveChat(String contactId) {
    return _chatService.resolveChat(contactId);
  }

  /// Resolve Conversation (older method)
  Future<ApiResponse<bool>> resolveConversation(String roomId) {
    return _chatService.resolveConversation(roomId);
  }

  /// Add Agent to Conversation
  Future<ApiResponse<bool>> addAgentToConversation(String roomId, String agentId, String agentName, {String chId = '', String ctId = ''}) {
    return _chatService.addAgentToConversation(roomId, agentId, agentName, chId: chId, ctId: ctId);
  }
}
