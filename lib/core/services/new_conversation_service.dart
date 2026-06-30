import '../model/api_response.dart';
import 'chat_service.dart';

// =====================================================================
// FITUR: Layanan Percakapan Baru (API)
// FILE: lib/core/services/new_conversation_service.dart
// BARIS AWAL: 7 (setelah komentar ini)
// FUNGSI: Service khusus untuk mengambil data yang dibutuhkan saat membuat percakapan baru. Mendelegasikan panggilan ke ChatService yang sudah teruji.
// =====================================================================
class NewConversationService {
  final ChatService _chatService = ChatService();

  /// Mengambil daftar Channels (Saluran) seperti WhatsApp, Telegram, dll.
  Future<ApiResponse<List<Map<String, dynamic>>>> getChannels() {
    return _chatService.getChannels();
  }

  /// Mengambil daftar Accounts (Akun)
  Future<ApiResponse<List<Map<String, dynamic>>>> getAccounts() {
    return _chatService.getAccounts();
  }

  /// Mengambil daftar Contacts (Kontak)
  Future<ApiResponse<List<Map<String, dynamic>>>> getContacts() {
    return _chatService.getContacts();
  }

  /// Mengambil daftar Groups (Grup)
  Future<ApiResponse<List<Map<String, dynamic>>>> getGroups() {
    return _chatService.getGroups();
  }

  /// Mengambil daftar Links (Tautan)
  Future<ApiResponse<List<Map<String, dynamic>>>> getLinks() {
    return _chatService.getLinks();
  }

  /// Mengambil daftar Campaigns (Kampanye)
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaigns() {
    return _chatService.getCampaigns();
  }

  /// Mengambil daftar Deals (Kesepakatan)
  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() {
    return _chatService.getDeals();
  }

  /// Mengambil daftar Agents (Agen)
  Future<ApiResponse<List<Map<String, dynamic>>>> getAgents() {
    return _chatService.getAgents();
  }
}
