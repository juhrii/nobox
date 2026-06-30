import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../app_config.dart';
import '../model/api_response.dart';
import 'chat_service.dart';

// =====================================================================
// FITUR: Layanan Detail Kontak
// FILE: lib/core/services/contact_detail_service.dart
// BARIS AWAL: 9 (setelah komentar ini)
// FUNGSI: Service khusus untuk mengelola detail kontak/room. Mendelegasikan panggilan ke ChatService yang sudah teruji.
// =====================================================================
class ContactDetailService {
  final ChatService _chatService = ChatService();

  /// Mengambil detail room lengkap (Tags, Funnel, Campaign, Deal, Notes, dll)
  Future<ApiResponse<Map<String, dynamic>>> getDetailRoom(String roomId) {
    return _chatService.getDetailRoom(roomId);
  }

  /// Memperbarui Info Kontak — dipisah menjadi Chatrooms/Update dan Contact/Update
  Future<ApiResponse<bool>> updateContactInfo(String contactId, Map<String, dynamic> contactData) {
    return _chatService.updateContactInfo(contactId, contactData);
  }

  /// Mengambil detail room yang diarsipkan
  Future<ApiResponse<Map<String, dynamic>>> getArchivedRoomDetail(String roomId) {
    return _chatService.getArchivedRoomDetail(roomId);
  }

  /// Mengubah status bisu (Mute) Agen AI
  Future<ApiResponse<bool>> toggleAiAgent(String contactId, bool isMuted) {
    return _chatService.toggleAiAgent(contactId, isMuted);
  }

  /// Mengubah status Perlu Balasan (Need Reply)
  Future<ApiResponse<bool>> toggleNeedReply(String contactId, bool needReply) {
    return _chatService.toggleNeedReply(contactId, needReply);
  }

  /// Menugaskan Chat ke Pengguna Saat Ini
  Future<ApiResponse<bool>> assignChat(String contactId) {
    return _chatService.assignChat(contactId);
  }

  /// Menyelesaikan / Menutup Chat
  Future<ApiResponse<bool>> resolveChat(String contactId) {
    return _chatService.resolveChat(contactId);
  }

  /// Menyelesaikan Percakapan (metode versi lama)
  Future<ApiResponse<bool>> resolveConversation(String roomId) {
    return _chatService.resolveConversation(roomId);
  }

  /// Menambahkan Agen ke Percakapan
  Future<ApiResponse<bool>> addAgentToConversation(String roomId, String agentId, String agentName, {String chId = '', String ctId = ''}) {
    return _chatService.addAgentToConversation(roomId, agentId, agentName, chId: chId, ctId: ctId);
  }
}
