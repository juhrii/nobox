import '../model/api_response.dart';
import 'chat_service.dart';

/// Service khusus untuk mengambil data filter (Tags, Funnels, Agents).
/// Mendelegasikan panggilan ke ChatService yang sudah teruji.
class FilterApiService {
  final ChatService _chatService = ChatService();

  /// Fetch list of Tags
  Future<ApiResponse<List<Map<String, dynamic>>>> getTags() {
    return _chatService.getTags();
  }

  /// Fetch list of Funnels
  Future<ApiResponse<List<Map<String, dynamic>>>> getFunnels() {
    return _chatService.getFunnels();
  }

  /// Fetch list of Agents
  Future<ApiResponse<List<Map<String, dynamic>>>> getAgents() {
    return _chatService.getAgents();
  }

  /// Fetch list of Channels
  Future<ApiResponse<List<Map<String, dynamic>>>> getChannels() {
    return _chatService.getChannels();
  }

  /// Fetch list of Accounts
  Future<ApiResponse<List<Map<String, dynamic>>>> getAccounts() {
    return _chatService.getAccounts();
  }
}
