import '../model/api_response.dart';
import 'chat_service.dart';

/// Service khusus untuk data yang dibutuhkan saat membuat percakapan baru.
/// Mendelegasikan panggilan ke ChatService yang sudah teruji.
class NewConversationService {
  final ChatService _chatService = ChatService();

  /// Fetch list of channels (WhatsApp, Telegram, etc.)
  Future<ApiResponse<List<Map<String, dynamic>>>> getChannels() {
    return _chatService.getChannels();
  }

  /// Fetch list of accounts
  Future<ApiResponse<List<Map<String, dynamic>>>> getAccounts() {
    return _chatService.getAccounts();
  }

  /// Fetch list of contacts
  Future<ApiResponse<List<Map<String, dynamic>>>> getContacts() {
    return _chatService.getContacts();
  }

  /// Fetch list of groups
  Future<ApiResponse<List<Map<String, dynamic>>>> getGroups() {
    return _chatService.getGroups();
  }

  /// Fetch list of links
  Future<ApiResponse<List<Map<String, dynamic>>>> getLinks() {
    return _chatService.getLinks();
  }

  /// Fetch list of campaigns
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaigns() {
    return _chatService.getCampaigns();
  }

  /// Fetch list of deals
  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() {
    return _chatService.getDeals();
  }

  /// Fetch list of agents
  Future<ApiResponse<List<Map<String, dynamic>>>> getAgents() {
    return _chatService.getAgents();
  }
}
