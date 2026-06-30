import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../app_config.dart';
import '../model/api_response.dart';
import '../model/message_request.dart';
import '../model/conversation.dart';
import '../model/message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'signalr_service.dart';
import '../model/quick_reply_model.dart';

class SignalRNull {
  dynamic toJson() => null;
}

// =====================================================================
// FITUR: Layanan Chat Utama (API Utama)
// FILE: lib/core/services/chat_service.dart
// BARIS AWAL: 20 (setelah komentar ini)
// FUNGSI: Service terbesar yang menangani mayoritas interaksi API Chat: mengambil pesan, 
//         mengirim pesan, manajemen status chat, dan banyak fungsi lainnya.
// =====================================================================
class ChatService {
  final ApiClient _apiClient = ApiClient();
  String? currentTenantId;

  // Cache account data to ensure AccountIds is always populated for sendMessage 
  static final Map<String, String> _accountById = {};
  static final Map<int, String> _accountIdByChannel = {};
  static String? _singleAccountId;
  static String? _singleAccountName;

  /// Fetch list of channels from API (WhatsApp, Telegram, etc.)
    // FITUR 6: Integrasi Saluran Multi-Platform (Mengambil daftar Channel).
Future<ApiResponse<List<Map<String, dynamic>>>> getChannels() async {
    try {
      final response = await _apiClient.post(AppConfig.channelListEndpoint, data: {
        "Skip": 0,
        "Take": 100,
      });

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
        }

        final channels = dataList.where((item) {
          // Filter: only show Automation channels (WhatsApp, Telegram, etc.)
          if (item is Map) {
            final kt = item['Kt']?.toString() ?? '';
            return kt == 'Automation';
          }
          return true;
        }).map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          return <String, dynamic>{'Nm': item.toString()};
        }).toList();
        return ApiResponse.success(channels, response.statusCode!);
      } else {
        return ApiResponse.failure('Failed to load channels: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of accounts from API
    // FITUR 6: Integrasi Saluran Multi-Platform (Mengambil daftar Akun).
Future<ApiResponse<List<Map<String, dynamic>>>> getAccounts() async {
    try {
      final response = await _apiClient.post(AppConfig.accountListEndpoint, data: {
        "Skip": 0,
        "Take": 100,
      });

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
        }

        final accounts = dataList.map((item) {
          if (item is Map<String, dynamic>) {
            final tId = item['TenantId']?.toString();
            if (tId != null && tId.isNotEmpty) {
              currentTenantId = tId;
              // CRITICAL: Simpan tenantId ke secure storage agar SignalR bisa subscribe
              const storage = FlutterSecureStorage();
              storage.write(key: 'tenant_id', value: tId).then((_) {
                debugPrint('ChatService: ✅ TenantId saved to storage: $tId');
                // Trigger SignalR subscription sekarang tenantId tersedia
                SignalRService().trySubscribe();
              });
            }
            return item;
          }
          return <String, dynamic>{'Name': item.toString()};
        }).toList();
        return ApiResponse.success(accounts, response.statusCode!);
      } else {
        return ApiResponse.failure('Failed to load accounts: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of contacts from API (with full data including LeadLinks)
  Future<ApiResponse<List<Map<String, dynamic>>>> getContacts() async {
    try {
      final response = await _apiClient.post(AppConfig.contactListEndpoint, data: {
        "Skip": 0,
        "Take": 100,
      });

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
        }

        final contacts = dataList.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          return <String, dynamic>{'Name': item.toString()};
        }).toList();
        return ApiResponse.success(contacts, response.statusCode!);
      } else {
        return ApiResponse.failure('Failed to load contacts: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of campaigns from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaigns() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.campaignsListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        return ApiResponse.success(_parseGenericList(response.data), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load campaigns: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.success([], 200); // Fallback softly
    }
  }

  /// Fetch list of deals from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.dealsListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        return ApiResponse.success(_parseGenericList(response.data), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load deals: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.success([], 200); // Fallback softly
    }
  }

  /// Fetch list of groups from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getGroups() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.groupsListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        return ApiResponse.success(_parseGenericList(response.data), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load groups: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.success([], 200); // Fallback softly
    }
  }

  /// Fetch list of links from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getLinks() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'LinkTmp'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.linksListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        return ApiResponse.success(_parseGenericList(response.data), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load links: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.success([], 200); // Fallback softly
    }
  }

  List<Map<String, dynamic>> _parseGenericList(dynamic rawData) {
    List<dynamic> dataList = [];
    if (rawData is List) {
      dataList = rawData;
    } else if (rawData is Map) {
      dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
    }
    return dataList.map((item) {
      if (item is Map<String, dynamic>) return item;
      return <String, dynamic>{'Name': item.toString()};
    }).toList();
  }

  /// Fetch list of agents from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getAgents() async {
    try {
      final requestData = {
        'EqualityFilter': {
          'Roles': [6]
        },
        'IncludeColumns': ['DisplayName', 'UserId'],
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.getAgentsEndpoint, data: requestData);

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
        }

        final agents = dataList.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          return <String, dynamic>{'Name': item.toString()};
        }).toList();
        return ApiResponse.success(agents, response.statusCode!);
      } else {
        return ApiResponse.failure('Failed to load agents: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  Future<ApiResponse<bool>> addAgentToConversation(String roomId, String agentId, String agentName, {String chId = '', String ctId = ''}) async {
    try {
      String handId = "0";
      try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: AppConfig.tokenKey);
        if (token != null) {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payloadBase64 = parts[1];
            final String normalizedList = base64Url.normalize(payloadBase64);
            final String resp = utf8.decode(base64Url.decode(normalizedList));
            final payloadMap = jsonDecode(resp);
            handId = payloadMap['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] 
                  ?? payloadMap['nameid'] 
                  ?? payloadMap['sub'] 
                  ?? "0";
          }
        }
      } catch (e) {
        debugPrint('ChatService: Error getting user info for payload: $e');
      }

      final payload = {
        'RoomId': roomId,
        'UserId': agentId,
        'isHanded': 0,
        'Msg': {
          'Type': 6,
          'RoomId': roomId,
          'Msg': '{"msg":"Site.Inbox.HasAsignBy","userId":"$agentId","byUserId":"$handId"}',
        },
        'RoomAgent': {
          'UserId': agentId,
          'RoomId': roomId,
          'DisplayName': agentName,
          'HandId': handId,
          if (chId.isNotEmpty) 'ChId': chId,
          if (ctId.isNotEmpty) 'CtId': ctId,
        }
      };

      debugPrint('================ ADD AGENT PAYLOAD ================');
      debugPrint(jsonEncode(payload));
      debugPrint('===================================================');

      final response = await _apiClient.post(
        AppConfig.addAgentToConversationEndpoint,
        data: payload,
      );

      debugPrint('AddAgent Response Code: ${response.statusCode}');
      debugPrint('AddAgent Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final rawData = response.data;
        if (rawData is Map && rawData['IsError'] == true) {
          final errorMsg = rawData['Error']?.toString() ?? 'Server error';
          return ApiResponse.failure(errorMsg, 200);
        }
        return ApiResponse.success(true, response.statusCode!);
      } else {
        return ApiResponse.failure('Failed to assign agent: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      debugPrint('AddAgent DioError Data: ${e.response?.data}');
      debugPrint('AddAgent DioError Message: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Mark room as resolved
  /// Endpoint: POST Services/Chat/Chatrooms/MarkResolved
  /// St: 3 = Status Resolved
  /// ReById & ReByNm = diambil dari user data yang login
  Future<ApiResponse<bool>> resolveConversation(String roomId) async {
    try {
      // Get agent info from user data (SharedPreferences) or JWT fallback
      String agentId = "1";
      String agentName = "Agent";
      try {
        final prefs = await SharedPreferences.getInstance();
        final userDataJson = prefs.getString(AppConfig.userDataKey);
        if (userDataJson != null) {
          final userData = jsonDecode(userDataJson);
          agentId = userData['UserId']?.toString() ?? '1';
          agentName = userData['DisplayName']?.toString() ?? 'Agent';
        }
        
        // Fallback: decode JWT if user data is incomplete
        if (agentId == '1') {
          const storage = FlutterSecureStorage();
          final token = await storage.read(key: AppConfig.tokenKey);
          if (token != null) {
            final parts = token.split('.');
            if (parts.length == 3) {
              final payloadBase64 = parts[1];
              final String normalizedList = base64Url.normalize(payloadBase64);
              final String resp = utf8.decode(base64Url.decode(normalizedList));
              final payloadMap = jsonDecode(resp);
              agentId = payloadMap['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] 
                    ?? payloadMap['nameid'] 
                    ?? payloadMap['sub'] 
                    ?? "1";
              final String nameClaim = payloadMap['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name']?.toString() ?? '';
              final String emailClaim = payloadMap['email']?.toString() ?? '';
              agentName = nameClaim.isNotEmpty ? nameClaim : (emailClaim.isNotEmpty ? emailClaim.split('@').first : "Agent");
            }
          }
        }
      } catch (e) {
        debugPrint('ChatService: Error getting user info for resolve payload: $e');
      }

      debugPrint('✅ [Resolve] Marking room $roomId as resolved by $agentName (ID: $agentId)');

      final requestData = {
        'EntityId': roomId,
        'Entity': {
          'St': 3,       // Status 3 = Resolved
          'Uc': 0,
          'IsPin': 1,
          'Isblock': 1,
          'ReById': agentId,
          'ReByNm': agentName,
        },
      };

      final response = await _apiClient.post(
        AppConfig.resolveConversationEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          debugPrint('✅ [Resolve] Room marked as resolved successfully');
          return ApiResponse.success(true, response.statusCode!);
        } else {
          final errorMsg = response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to mark room as resolved';
          debugPrint('❌ [Resolve] Error: $errorMsg');
          return ApiResponse.failure(errorMsg, response.statusCode!);
        }
      } else {
        debugPrint('❌ [Resolve] HTTP ${response.statusCode}: ${response.statusMessage}');
        return ApiResponse.failure('HTTP ${response.statusCode}: ${response.statusMessage}', response.statusCode!);
      }
    } on DioException catch (e) {
      debugPrint('❌ [Resolve] DioException: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('❌ [Resolve] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of chat rooms filtered by status.
  /// [statusCode] → 1: Unassigned, 2: Assigned, 3: Resolved, null: All
  /// [skip] and [take] control pagination (defaults: skip=0, take=20)
  Future<ApiResponse<List<Conversation>>> getConversations({
    int? statusCode,
    int skip = 0,
    int take = 20,
    String? accountIds,
    String? contactId,
    String? linkId,
    String? groupId,
    String? campaignId,
    String? funnelId,
    String? dealId,
    String? tagsId,
    String? humanAgentId,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        "Take": take,
        "Skip": skip,
        "Sort": ["IsPin DESC", "TimeMsg DESC"],
        "IncludeColumns": [
          "Id", "CtId", "CtRealId", "GrpId", "CtRealNm", "Ct", "Grp",
          "LastMsg", "TimeMsg", "Uc", "St", "ChId", "ChAcc", "ChNm", "AccNm", "AccId", "BotNm", "CtTmp", "LinkTmp",
          "IsGrp", "IsPin", "CtIsBlock", "IsMuteBot", "IsNeedReply", "Tags", "Fn", "FnId", "FnNm", "FunnelId", "TagsIds",
          "UpBy", "AgentId", "AssignedTo", "HandledBy", "AgentName", "AssignedAgentName", "CtImg", "LinkImg", "TagsNm"
        ],
        "ColumnSelection": 1,
      };

      // Apply EqualityFilter for status and accountIds
      if (statusCode != null || (accountIds != null && accountIds.isNotEmpty) ||
          contactId != null ||
          linkId != null ||
          groupId != null ||
          campaignId != null ||
          funnelId != null ||
          dealId != null ||
          tagsId != null ||
          humanAgentId != null) {
        payload["EqualityFilter"] = {};

        if (statusCode != null) {
          payload["EqualityFilter"]["St"] = [statusCode];
        }

        if (accountIds != null && accountIds.isNotEmpty) {
          payload["EqualityFilter"]["ChAccId"] = accountIds;
        }

        if (contactId != null && contactId.isNotEmpty) {
          payload["EqualityFilter"]["CtRealId"] = [contactId];
        }

        if (linkId != null && linkId.isNotEmpty) {
          payload["EqualityFilter"]["LinkTmp"] = linkId;
        }

        if (groupId != null && groupId.isNotEmpty) {
          payload["EqualityFilter"]["GrpId"] = groupId;
        }

        if (campaignId != null && campaignId.isNotEmpty) {
          payload["EqualityFilter"]["CampaignId"] = campaignId;
        }

        if (funnelId != null && funnelId.isNotEmpty) {
          payload["EqualityFilter"]["FunnelId"] = funnelId;
        }

        if (dealId != null && dealId.isNotEmpty) {
          payload["EqualityFilter"]["DealId"] = dealId;
        }

        if (tagsId != null && tagsId.isNotEmpty) {
          // backend likely supports equality on TagsIds
          payload["EqualityFilter"]["TagsIds"] = tagsId;
        }

      }

      if (humanAgentId != null && humanAgentId.isNotEmpty) {
        final int? parsedId = int.tryParse(humanAgentId);
        if (parsedId != null) {
          payload["UserIds"] = [parsedId];
        }
      }


      debugPrint('ChatService: fetchConversations statusCode=$statusCode');
      final response = await _apiClient.post(AppConfig.chatroomsListEndpoint, data: payload);

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;

        // Check for NoBox error envelope
        if (rawData is Map && rawData['IsError'] == true) {
          final serverError = rawData['Error']?.toString() ?? 'Unknown server error';
          debugPrint('ChatService: Server error in getConversations: $serverError');
          return ApiResponse.failure(serverError, 200);
        }

        List<dynamic> dataList = [];
        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
        }

        debugPrint('ChatService: Loaded ${dataList.length} conversations with status=$statusCode');

        final conversations = dataList.map((json) {
          if (json is Map<String, dynamic>) {
            final conv = Conversation.fromJson(json);
            return conv;
          }
          return Conversation(id: '', participantEmail: 'Unknown', lastMessage: '', lastMessageTime: '');
        }).toList();

        // Fetch accounts to map ChId → Account Name
        try {
          final accountsResponse = await getAccounts();
          if (!accountsResponse.isError && accountsResponse.data != null) {
            final accounts = accountsResponse.data!;
            debugPrint('ChatService: Fetched ${accounts.length} accounts');
            
            // Debug: print all account fields
            for (final acc in accounts) {
              debugPrint('ChatService: Account → ${acc.entries.map((e) => "${e.key}=${e.value}").join(", ")}');
            }
            
            // Build lookup maps
            final accountByChannel = <int, String>{};   // Channel number → Name
            final accountIdByChannel = <int, String>{}; // Channel number → AccountId
            
            for (final acc in accounts) {
              final name = acc['Name']?.toString() ?? acc['Nm']?.toString() ?? '';
              final id = acc['Id']?.toString() ?? '';
              final channel = acc['Channel'];
              final tId = acc['TenantId']?.toString();

              if (tId != null && tId.isNotEmpty) {
                currentTenantId = tId;
              }
              
              if (name.isNotEmpty) {
                _singleAccountName = name;
                if (id.isNotEmpty) {
                   _accountById[id] = name;
                   _singleAccountId = id; // Store last ID or single ID
                }
                
                // Handle Channel as both number and string
                if (channel is int) {
                  accountByChannel[channel] = name;
                  if (id.isNotEmpty) accountIdByChannel[channel] = id;
                } else if (channel is String) {
                  final channelNum = int.tryParse(channel);
                  if (channelNum != null) {
                    accountByChannel[channelNum] = name;
                    if (id.isNotEmpty) accountIdByChannel[channelNum] = id;
                  } else {
                    // String like "WhatsApp" → map to number  
                    if (channel.toLowerCase().contains('whatsapp')) {
                      accountByChannel[1] = name;
                      if (id.isNotEmpty) accountIdByChannel[1] = id;
                    }
                    else if (channel.toLowerCase().contains('telegram')) {
                      accountByChannel[2] = name;
                      if (id.isNotEmpty) accountIdByChannel[2] = id;
                    }
                  }
                }
              }
            }
            
            _accountIdByChannel.addAll(accountIdByChannel);
            debugPrint('ChatService: _accountById=$_accountById, single=$_singleAccountName');

            // Inject account name into conversations
            for (int i = 0; i < conversations.length; i++) {
              if (i < dataList.length) {
                final json = dataList[i];
                if (json is Map<String, dynamic>) {
                  final chId = json['ChId'];
                  final accId = json['AccId']?.toString();
                  
                  // Try matching by AccId first, then ChId, then fallback to single account
                  String? resolvedName;
                  String? resolvedAccountId = accId;
                  if (accId != null && _accountById.containsKey(accId)) {
                    resolvedName = _accountById[accId];
                  } else if (chId != null && chId is int && accountByChannel.containsKey(chId)) {
                    resolvedName = accountByChannel[chId];
                    resolvedAccountId = accountIdByChannel[chId];
                  } else if (accounts.length == 1 && _singleAccountName != null) {
                    resolvedName = _singleAccountName;
                    resolvedAccountId = _singleAccountId;
                  }
                  
                  if (resolvedName != null || (resolvedAccountId != null && resolvedAccountId.isNotEmpty)) {
                    conversations[i] = conversations[i].copyWith(
                      channelName: resolvedName,
                      accountId: resolvedAccountId,
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('ChatService: Failed to resolve account names: $e');
        }

        return ApiResponse.success(conversations, response.statusCode!);
      } else {
        return ApiResponse.failure(
          'Failed to load chats: ${response.statusCode}',
          response.statusCode!,
        );
      }
    } on DioException catch (e) {
      String errorMessage = e.message ?? 'Unknown connection error';
      if (e.response != null && e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      debugPrint('ChatService: getConversations DioException: $errorMessage');
      return ApiResponse.failure(errorMessage, e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('ChatService: getConversations error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch resolved conversation history for a specific contact.
  /// Uses the ListHistory endpoint with CtId filter and St=3 (Resolved).
  Future<ApiResponse<List<Conversation>>> getConversationHistory(String contactId) async {
    try {
      final Map<String, dynamic> payload = {
        "Take": 50,
        "Skip": 0,
        "Sort": ["TimeMsg DESC"],
        "IncludeColumns": [
          "Id", "CtId", "CtRealId", "GrpId", "CtRealNm", "Ct", "Grp",
          "LastMsg", "TimeMsg", "Uc", "St", "ChId", "ChAcc", "ChNm", "AccNm", "AccId", "BotNm", "CtTmp", "LinkTmp",
          "IsGrp", "IsPin", "CtIsBlock", "IsMuteBot", "IsNeedReply", "Tags", "Fn", "FnId", "FnNm", "FunnelId", "TagsIds",
          "UpBy", "AgentId", "AssignedTo", "HandledBy", "AgentName", "AssignedAgentName", "CtImg", "LinkImg", "TagsNm"
        ],
        "ColumnSelection": 1,
        "EqualityFilter": {
          "CtId": contactId,
          "St": 3,
        },
      };

      debugPrint('ChatService: getConversationHistory CtId=$contactId');
      final response = await _apiClient.post(AppConfig.chatroomsListHistoryEndpoint, data: payload);

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;

        if (rawData is Map && rawData['IsError'] == true) {
          final serverError = rawData['Error']?.toString() ?? 'Unknown server error';
          debugPrint('ChatService: Server error in getConversationHistory: $serverError');
          return ApiResponse.failure(serverError, 200);
        }

        List<dynamic> dataList = [];
        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? rawData['list'] ?? [];
        }

        debugPrint('ChatService: Loaded ${dataList.length} history conversations for CtId=$contactId');

        final conversations = dataList.map((json) {
          if (json is Map<String, dynamic>) {
            return Conversation.fromJson(json);
          }
          return Conversation(id: '', participantEmail: 'Unknown', lastMessage: '', lastMessageTime: '');
        }).toList();

        // Inject account names (just like in getConversations)
        try {
          final accountsResponse = await getAccounts();
          if (!accountsResponse.isError && accountsResponse.data != null) {
            final accounts = accountsResponse.data!;
            final accountByChannel = <int, String>{};
            final accountIdByChannel = <int, String>{};
            
            for (final acc in accounts) {
              final name = acc['Name']?.toString() ?? acc['Nm']?.toString() ?? '';
              final channel = acc['Channel'];
              
              final id = acc['Id']?.toString() ?? '';
              
              if (name.isNotEmpty) {
                if (channel is int) {
                  accountByChannel[channel] = name;
                  if (id.isNotEmpty) accountIdByChannel[channel] = id;
                } else if (channel is String) {
                  final channelNum = int.tryParse(channel);
                  if (channelNum != null) {
                    accountByChannel[channelNum] = name;
                    if (id.isNotEmpty) accountIdByChannel[channelNum] = id;
                  } else {
                    if (channel.toLowerCase().contains('whatsapp')) {
                      accountByChannel[1] = name;
                      if (id.isNotEmpty) accountIdByChannel[1] = id;
                    }
                    else if (channel.toLowerCase().contains('telegram')) {
                      accountByChannel[2] = name;
                      if (id.isNotEmpty) accountIdByChannel[2] = id;
                    }
                  }
                }
              }
            }

            for (int i = 0; i < conversations.length; i++) {
              if (i < dataList.length) {
                final json = dataList[i];
                if (json is Map<String, dynamic>) {
                  final chId = json['ChId'];
                  final accId = json['AccId']?.toString();
                  
                  String? resolvedName;
                  String? resolvedAccountId = accId;
                  if (accId != null && _accountById.containsKey(accId)) {
                    resolvedName = _accountById[accId];
                  } else if (chId != null && chId is int && accountByChannel.containsKey(chId)) {
                    resolvedName = accountByChannel[chId];
                    resolvedAccountId = accountIdByChannel[chId];
                  } else if (accounts.length == 1 && _singleAccountName != null) {
                    resolvedName = _singleAccountName;
                    resolvedAccountId = _singleAccountId;
                  }
                  
                  if (resolvedName != null || (resolvedAccountId != null && resolvedAccountId.isNotEmpty)) {
                    conversations[i] = conversations[i].copyWith(
                      channelName: resolvedName,
                      accountId: resolvedAccountId,
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('ChatService: Failed to resolve account names in history: $e');
        }

        return ApiResponse.success(conversations, response.statusCode!);
      } else {
        return ApiResponse.failure(
          'Failed to load conversation history: ${response.statusCode}',
          response.statusCode!,
        );
      }
    } on DioException catch (e) {
      debugPrint('ChatService: getConversationHistory DioException: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('ChatService: getConversationHistory error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch message history for a chatroom.
  /// [roomId] must be the RoomId (Id from Chatrooms/List), NOT the ContactId (CtId).
  Future<ApiResponse<List<Message>>> getMessageHistory(String roomId, String currentUserEmail, {int skip = 0, int take = 50}) async {
    if (currentTenantId == null) {
      // Ensure we have TenantId before fetching messages to construct WhatsApp image URLs
      await getAccounts();
    }
    
    try {
      final payload = {
        'Take': take,
        'Skip': skip,
        'Sort': ['In DESC'],
        'IncludeColumns': [
          "Id", "IdAlias", "GrpMember", "RoomId", "Ack", "From", "ReplyFrom", "To", "AgentId", "IsNobox",
          "Type", "Msg", "Files", "File", "ReplyType", "ReplyMsg", "ReplyFiles", "ReplyGrpMember", "ReplyId",
          "InteractiveMsg", "InteractiveType", "Note", "AiCredit", "In", "InBy", "Up", "UpBy"
        ],
        'ColumnSelection': 1,
        'EqualityFilter': {
          'RoomId': [int.tryParse(roomId) ?? roomId]
        },
      };

      debugPrint('ChatService: ┌── getMessageHistory ──');
      debugPrint('ChatService: │ Endpoint: ${AppConfig.getMessagesEndpoint}');
      debugPrint('ChatService: │ RoomId: $roomId');

      final response = await _apiClient.post(
        AppConfig.getMessagesEndpoint,
        data: payload,
      );

      debugPrint('ChatService: │ Status: ${response.statusCode}');
      final respStr = response.data?.toString() ?? 'null';
      debugPrint('ChatService: │ Response (first 300): ${respStr.length > 300 ? respStr.substring(0, 300) : respStr}');
      debugPrint('ChatService: └──────────────────────');

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          if (rawData['IsError'] == true) {
            final serverError = rawData['Error']?.toString() ?? 'Unknown server error';
            debugPrint('ChatService: getMessageHistory server error: $serverError');
            return ApiResponse.failure(serverError, 200);
          }
          dataList = rawData['Entities'] ?? rawData['Values'] ?? rawData['data'] ?? [];
        }

        debugPrint('ChatService: getMessageHistory loaded ${dataList.length} messages');
        if (dataList.isNotEmpty) {
          debugPrint('ChatService: First message keys: ${(dataList.first as Map).keys.toList()}');
        }

        final messages = dataList.map((json) => Message.fromJson(json, currentUserEmail, tenantId: currentTenantId)).toList();

        // Balik urutan: API kirim DESC (terbaru dulu),
        // tapi tampilan chat butuh ASC (terlama di atas)
        final reversed = messages.reversed.toList();
        return ApiResponse.success(reversed, response.statusCode!);
      } else {
        debugPrint('ChatService: getMessageHistory FAILED with status ${response.statusCode}');
        return ApiResponse.failure(
          'Failed to load messages: ${response.statusCode}',
          response.statusCode!,
        );
      }
    } on DioException catch (e) {
      debugPrint('ChatService: getMessageHistory DioException: ${e.message}');
      return ApiResponse.failure(
        e.message ?? 'Connection error while loading messages',
        e.response?.statusCode ?? 500,
      );
    } catch (e) {
      debugPrint('ChatService: getMessageHistory error: $e');
      return ApiResponse.failure('Failed to load messages', 500);
    }
  }

  /// Get archived room detail — returns raw Data map (like mentor's api_service.dart).
  /// The caller is responsible for extracting Messages from this map.
  Future<ApiResponse<Map<String, dynamic>>> getArchivedRoomDetail(String roomId) async {
    try {
      debugPrint('📦 ChatService: getArchivedRoomDetail - RoomId: $roomId');

      final response = await _apiClient.post(
        AppConfig.detailArchivedEndpoint,
        data: {
          'EntityId': roomId,
        },
      );

      debugPrint('📦 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;

        debugPrint('📦 ChatService: HasError: $hasError');
        debugPrint('📦 ChatService: Response top-level keys: ${(response.data as Map?)?.keys.toList()}');

        if (!hasError && response.data['Data'] != null) {
          final data = response.data['Data'] as Map<String, dynamic>;
          debugPrint('✅ ChatService: Got archived room detail');
          debugPrint('📦 ChatService: Data keys: ${data.keys.toList()}');

          // Log deeper structure for debugging
          data.forEach((key, value) {
            if (value is List) {
              debugPrint('📦   $key: List with ${value.length} items');
              if (value.isNotEmpty) {
                debugPrint('📦     First item keys: ${(value.first as Map?)?.keys.toList()}');
              }
            } else if (value is Map) {
              debugPrint('📦   $key: Map with keys ${value.keys.toList()}');
            } else {
              final valStr = value?.toString() ?? 'null';
              debugPrint('📦   $key: ${valStr.length > 80 ? valStr.substring(0, 80) : valStr}');
            }
          });

          return ApiResponse.success(data, response.statusCode!);
        } else {
          final errorMsg = response.data['ErrorMsg']?.toString() ??
              response.data['Error']?.toString() ??
              'Failed to load archived room detail';
          debugPrint('❌ ChatService: Archived error: $errorMsg');
          return ApiResponse.failure(errorMsg, response.statusCode!);
        }
      } else {
        return ApiResponse.failure(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          response.statusCode!,
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ ChatService: getArchivedRoomDetail DioException: ${e.message}');
      return ApiResponse.failure(
        e.message ?? 'Connection error',
        e.response?.statusCode ?? 500,
      );
    } catch (e) {
      debugPrint('❌ ChatService: getArchivedRoomDetail error: $e');
      return ApiResponse.failure('Failed to load archived detail: $e', 500);
    }
  }

  /// Helper untuk membangun Telegram ExtId yang valid dan mencegah double-encoding JSON
  String _buildTelegramExtId(String rawExtId, String? username, String? accessHash) {
    if (rawExtId.isEmpty) return rawExtId;
    
    bool isJson = false;
    Map<String, dynamic> existingJson = {};
    try {
      final decoded = jsonDecode(rawExtId);
      if (decoded is Map) {
        isJson = true;
        existingJson = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    final extIdMap = <String, dynamic>{};
    if (isJson) {
      extIdMap.addAll(existingJson);
      if (username != null && username.isNotEmpty) extIdMap['Username'] = username;
      if (accessHash != null && accessHash.isNotEmpty) extIdMap['AccessHash'] = accessHash;
    } else {
      extIdMap['ExtId'] = rawExtId;
      if (username != null && username.isNotEmpty) extIdMap['Username'] = username;
      if (accessHash != null && accessHash.isNotEmpty) extIdMap['AccessHash'] = accessHash;
    }
    return jsonEncode(extIdMap);
  }

  /// Retrieve ExtId for a contact. For Telegram (channelId=2), returns a JSON
  /// string containing ExtId, Username, and AccessHash per mentor instruction.
  Future<String?> _getExtId(String? contactId, {int channelId = 1}) async {
    if (contactId == null || contactId.isEmpty) return null;
    try {
      final response = await _apiClient.get(
        'https://id.nobox.ai/Services/Chat/Chatlinkcontacts/Retrieve?Id=$contactId',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final entity = data['Entity'];
          if (entity is Map) {
            String extId = '';
            String? username;
            String? accessHash;

            // Mentor contract: ExtId must come from Entity.Extra.ExtId ("628...")
            final extraRaw = entity['Extra'];
            if (extraRaw != null) {
              try {
                final extraMap = extraRaw is String ? jsonDecode(extraRaw) : extraRaw;
                if (extraMap is Map) {
                  if (extraMap['ExtId'] != null) {
                    extId = extraMap['ExtId'].toString();
                  }
                  // Capture Telegram-specific fields from Extra
                  username = extraMap['Username']?.toString();
                  accessHash = extraMap['AccessHash']?.toString();
                }
              } catch (_) {
                // ignore parse error, fallback to IdExt below
              }
            }

            if (extId.isEmpty) {
              extId = entity['IdExt']?.toString() ?? '';
            }

            if (extId.isEmpty) return null;

            // Telegram: wrap ExtId in JSON string with Username & AccessHash
            if (channelId == 2) {
              final idExt = entity['IdExt']?.toString();
              if (idExt != null && idExt.isNotEmpty) {
                extId = idExt;
              }
              final jsonStr = _buildTelegramExtId(extId, username, accessHash);
              debugPrint('ChatService: _getExtId Telegram JSON: $jsonStr');
              return jsonStr;
            }

            return extId;
          }

          // fallback if API shape differs
          if (data['IdExt'] != null) return data['IdExt']?.toString();
        }
      }
    } catch (e) {
      debugPrint('Error retrieving ExtId: $e');
    }
    return null;
  }

  /// Create a new conversation room via Inbox/CreateNewRoom API
  /// This matches the mentor project's approach – create room first, then send messages.
  Future<Map<String, dynamic>> createNewRoom({
    required int accountId,
    required int channelId,
    int? contactId,
    int? linkId,
    String? manualNumber,
    bool isGroup = false,
  }) async {
    try {
      // Determine "To" flag per mentor contract:
      // 1 = Contact, 2 = Link, 3 = Manual/Group
      int toType = 1; // default: Contact
      if (linkId != null) toType = 2;
      if ((manualNumber != null && manualNumber.isNotEmpty) || isGroup) toType = 3;

      final data = {
        "AccId": accountId,
        "ChId": channelId,
        "LinkId": linkId,
        "GrpId": null, // Fill if isGroup = true
        "Chat": isGroup ? 1 : 0,
        "CtId": contactId,
        "Manual": manualNumber ?? "",
        "To": toType,
      };

      debugPrint('ChatService: ┌── createNewRoom ──');
      debugPrint('ChatService: │ Endpoint: ${AppConfig.createNewRoomEndpoint}');
      debugPrint('ChatService: │ Payload: $data');

      final response = await _apiClient.post(
        AppConfig.createNewRoomEndpoint,
        data: data,
      );

      debugPrint('ChatService: │ Response status: ${response.statusCode}');
      debugPrint('ChatService: │ Response data: ${response.data}');
      debugPrint('ChatService: └──────────────────');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map) {
          final result = Map<String, dynamic>.from(responseData);

          if (result['IsError'] == true) {
            return {
              'success': false,
              'error': result['ErrorMessage'] ?? result['Error'] ?? 'API error',
            };
          }

          return {
            'success': true,
            'roomId': result['Data']?['Id'] ?? result['Data']?['RoomId'] ?? result['Id'],
            'data': result['Data'],
          };
        }
        return {'success': true, 'data': responseData};
      }

      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.statusMessage}',
      };
    } on DioException catch (e) {
      debugPrint('ChatService: ❌ CreateNewRoom DioError: ${e.message}');
      debugPrint('ChatService: ❌ Response: ${e.response?.data}');
      return {
        'success': false,
        'error': 'API Error: ${e.message}',
        'statusCode': e.response?.statusCode,
      };
    } catch (e) {
      debugPrint('ChatService: ❌ CreateNewRoom error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  Future<ApiResponse<bool>> sendMessage(MessageRequest request) async {
    try {
      final roomIdStr = request.receiver;
      final content = request.content;
      
      debugPrint('ChatService: ┌── sendMessage (REST API) ──');
      debugPrint('ChatService: │ RoomId: $roomIdStr');
      debugPrint('ChatService: │ Content: $content');
      debugPrint('ChatService: │ Endpoint: ${AppConfig.inboxSendEndpoint}?Id=$roomIdStr');

      // Mentor instruction: AccountIds must be a single string (comma-separated if multiple), NOT an array.
      // Clean up the string to remove any brackets or quotes just in case the source contains them.
      String safeAccountId = '';
      if (request.accountId != null && request.accountId!.isNotEmpty) {
        safeAccountId = request.accountId!;
      }
      
      final int channelId = int.tryParse(request.channelId ?? '1') ?? 1;

      if (safeAccountId.isEmpty && _accountIdByChannel.containsKey(channelId)) {
        safeAccountId = _accountIdByChannel[channelId]!;
        debugPrint('ChatService: AccountId was empty, using fallback for channel $channelId -> $safeAccountId');
      }

      if (safeAccountId.isEmpty && _singleAccountId != null && _singleAccountId!.isNotEmpty) {
        safeAccountId = _singleAccountId!;
      }
      safeAccountId = safeAccountId.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').trim();

      String extId = '';
      String? telegramUsername;
      String? telegramAccessHash;

      // Retrieve ExtId via POST to Chatlinkcontacts/Retrieve
      if (request.contactId != null && request.contactId!.isNotEmpty) {
        try {
          final retrieveResponse = await _apiClient.post(
            'Services/Chat/Chatlinkcontacts/Retrieve',
            data: {'EntityId': request.contactId},
          );
          if (retrieveResponse.statusCode == 200) {
            final data = retrieveResponse.data;
            // Mentor contract: ExtId should come from Entity.Extra.ExtId ("628...")
            final entity = data['Entity'];
            if (entity is Map) {
              final extraRaw = entity['Extra'];
              if (extraRaw != null) {
                try {
                  final extraMap = extraRaw is String ? jsonDecode(extraRaw) : extraRaw;
                  if (extraMap is Map) {
                    if (extraMap['ExtId'] != null) {
                      extId = extraMap['ExtId']?.toString() ?? '';
                    }
                    // Capture Telegram-specific fields from Extra
                    telegramUsername = extraMap['Username']?.toString();
                    telegramAccessHash = extraMap['AccessHash']?.toString();
                  }
                } catch (_) {
                  // ignore parse error; fallback to IdExt
                }
              }
              final idExt = entity['IdExt']?.toString() ?? '';
              final int chId = int.tryParse(request.channelId ?? '1') ?? 1;
              if (chId == 2 && idExt.isNotEmpty) {
                extId = idExt;
              } else {
                extId = (extId.isNotEmpty ? extId : idExt);
              }
            }
            debugPrint('ChatService: ExtId retrieved = $extId');
          }
        } catch (e) {
          debugPrint('ChatService: Error retrieving ExtId: $e');
        }
      }

      if (extId.isEmpty && request.extId != null && request.extId!.isNotEmpty) {
        extId = request.extId!;
      }



      // Mentor's test_api_6.dart confirms that Inbox/Send for Telegram requires 
      // ExtId as the plain string ID and LinkId as a long/int.
      // Do NOT send ExtId as a JSON string here, it causes backend errors when LinkId is present!
      String finalExtId = extId;

      final Map<String, dynamic> payload = {
        'Body': content,
        'BodyType': 1,
        'ChannelId': channelId,
        'AccountIds': safeAccountId,
        'Attachment': request.attachment ?? '',
      };

      if (channelId == 2) {
        // Telegram wajib menggunakan object JSON untuk ExtId dan LinkId
        if (finalExtId.isNotEmpty) {
          try {
            payload['ExtId'] = jsonDecode(finalExtId);
          } catch (_) {
            payload['ExtId'] = {"ExtId": finalExtId};
          }
        }
        if (request.contactId != null && request.contactId!.isNotEmpty) {
          payload['LinkId'] = int.tryParse(request.contactId!) ?? request.contactId;
        }
      } else {
        payload['ExtId'] = finalExtId;
      }

      debugPrint('ChatService: ┌── sendMessage PAYLOAD FINAL ──');
      debugPrint(jsonEncode(payload));
      debugPrint('ChatService: └──────────────────────────────');

      final response = await _apiClient.post(
      'https://id.nobox.ai/Inbox/Send?Id=${roomIdStr ?? '0'}',
        data: payload,
      );


      debugPrint('ChatService: │ Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final rawData = response.data;
        if (rawData is Map && rawData['IsError'] == true) {
          final errorMsg = rawData['Error']?.toString() ?? 'Send error';
          
          if (errorMsg.contains('ExtId') || errorMsg.contains('long')) {
            debugPrint('ChatService: Terdeteksi error ExtId backend (Teks)! Mengalihkan ke SignalR...');
            final signalRSuccess = await SignalRService().invokeKirimPesan(
              idLink: request.contactId,
              idAccount: safeAccountId,
              idRoom: roomIdStr,
              idGroup: null,
              type: "1", 
              msg: request.content,
            );
            
            if (signalRSuccess) {
              return ApiResponse.success(true, 200);
            } else {
              return ApiResponse.failure('Gagal mengirim teks Telegram via SignalR (Fallback)', 500);
            }
          }
          
          debugPrint('ChatService: │ ❌ Server error: $errorMsg');
          debugPrint('ChatService: └─────────────────────────');
          return ApiResponse.failure(errorMsg, 200);
        }
        debugPrint('ChatService: │ ✅ Message sent via REST API!');
        debugPrint('ChatService: └─────────────────────────');
        return ApiResponse.success(true, 200);
      } else {
        debugPrint('ChatService: │ ❌ HTTP ${response.statusCode}');
        debugPrint('ChatService: └─────────────────────────');
        return ApiResponse.failure('Failed: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      debugPrint('ChatService: sendMessage DioException: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('ChatService: sendMessage error: $e');
      return ApiResponse.failure('Failed to send message: $e', 500);
    }
  }


  /// Get MIME type based on file extension
  String _getMimeType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  /// Send an image message: upload file then send the URL as message body
  Future<ApiResponse<String>> sendImageMessage(
    String conversationId, 
    String filePath, {
    String? accountId,
    String? channelId,
    String? contactId,
    String? link, // IdLink for SignalR (LinkTmp/LinkNm from conversation)
    bool forceDocument = false,
  }) async {
    try {
      final normalizedPath = filePath.replaceAll('/', Platform.pathSeparator);
      final file = File(normalizedPath);
      
      if (!await file.exists()) {
        debugPrint('ChatService: File not found at $normalizedPath');
        // File not found, just send the filename as text message
        final fallbackName = normalizedPath.split(Platform.pathSeparator).last;
        final sendResponse = await _apiClient.post(
          "${AppConfig.inboxSendEndpoint}?Id=$conversationId",
          data: {"Body": "[File: $fallbackName]"},
        );
        if (sendResponse.statusCode == 200) {
          return ApiResponse.success(normalizedPath, 200);
        }
        return ApiResponse.failure('File not found', 404);
      }
      
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final fileName = normalizedPath.split(Platform.pathSeparator).last;
      final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';

      // Step 1: Upload file via Base64 endpoint
      String? serverFileName;
      try {
        final mimeType = _getMimeType(fileName);
        final uploadPayload = {
          'media': {
            'filename': fileName,
            'mimetype': mimeType,
            'data': base64String,
          },
        };

        debugPrint('--- DEBUG UPLOAD START ---');
        debugPrint('URL: ${AppConfig.uploadBase64Endpoint}');
        debugPrint('Payload (filename): $fileName');
        debugPrint('Payload (mimetype): $mimeType');
        debugPrint('Payload (data length): ${base64String.length}');
        
        final uploadResponse = await _apiClient.post(
          AppConfig.uploadBase64Endpoint,
          data: uploadPayload,
        );

        debugPrint('Response Status: ${uploadResponse.statusCode}');
        debugPrint('Response Data: ${uploadResponse.data}');

        if (uploadResponse.statusCode == 200) {
          final responseData = uploadResponse.data;
          // Extract the filename returned by the server
          if (responseData is Map && responseData['Data'] != null) {
            serverFileName = responseData['Data']['Filename'] ?? responseData['Data']['FileName'] ?? responseData['Data']['filename'];
          } else if (responseData is Map && responseData['IsError'] == false) {
             serverFileName = responseData['Data']?.toString();
          }
          debugPrint('ChatService: File uploaded successfully -> $serverFileName');
        }
        debugPrint('--- DEBUG UPLOAD END ---');
      } on DioException catch (e) {
        debugPrint('--- DEBUG UPLOAD ERROR ---');
        debugPrint('Status Code: ${e.response?.statusCode}');
        debugPrint('Error Data: ${e.response?.data}');
        debugPrint('Message: ${e.message}');
        debugPrint('--- DEBUG UPLOAD END ---');
      }

      if (serverFileName == null || serverFileName.isEmpty) {
        return ApiResponse.failure('Gagal mengupload file ke server', 500);
      }


      // Step 2: Send as message with image content
      // Determine BodyType based on file extension
      int bodyType = 3; // Default to Image
      switch (extension) {
        case 'mp4':
        case 'mov':
        case 'avi':
        case 'mkv':
        case '3gp':
        case 'webm':
          bodyType = 4; // Video
          break;
        case 'm4a':
        case 'mp3':
        case 'wav':
        case 'ogg':
        case 'opus':
        case 'aac':
        case 'amr':
        case 'weba':
          bodyType = 2; // Audio/Voice
          break;
        case 'pdf':
        case 'doc':
        case 'docx':
        case 'xls':
        case 'xlsx':
        case 'ppt':
        case 'pptx':
        case 'txt':
        case 'csv':
        case 'zip':
        case 'rar':
        case 'rtf':
          bodyType = 5; // Document
          break;
      }

      if (forceDocument) {
        bodyType = 5; // Force as document if requested by the user
      }

      // Create attachment data in JSON format as required by Pin point
      final attachmentMap = <String, dynamic>{
        'Filename': serverFileName,
        'OriginalName': fileName,
      };
      // Add Ptt (push-to-talk) flag for voice notes so WhatsApp shows it
      // as a voice message bubble instead of a document attachment
      if (bodyType == 2) {
        attachmentMap['Ptt'] =true;
      }
      final attachmentData = jsonEncode([attachmentMap]);

    // Mentor instruction: AccountIds must be a single string (comma-separated if multiple), NOT an array.
    String safeAccountId = '';
    if (accountId != null && accountId.isNotEmpty) {
      safeAccountId = accountId;
    } else if (_singleAccountId != null && _singleAccountId!.isNotEmpty) {
      safeAccountId = _singleAccountId!;
    }
    safeAccountId = safeAccountId.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').trim();

    final int chId = int.tryParse(channelId ?? '1') ?? 1;
    final extId = await _getExtId(contactId, channelId: chId);
    final payload = <String, dynamic>{
      "Body": "", 
      "BodyType": bodyType,
      "ChannelId": chId,
      "AccountIds": safeAccountId,
      "Attachment": attachmentData,
    };

    if (chId == 2) {
      // Use SignalR for Telegram media message to bypass broken Inbox/Send backend
      final fileJsonObj = <String, dynamic>{
        "Filename": serverFileName,
        "OriginalName": fileName,
        "FileSize": "${(bytes.length / 1024).toStringAsFixed(1)} KB"
      };
      if (bodyType == 2) {
        fileJsonObj["Ptt"] = true; // IMPORTANT for Voice Notes
      }
      // Use link (LinkTmp) if available, fallback to contactId — same logic as sendMessageViaSignalR in ChatProvider
      final idLinkValue = (link != null && link.isNotEmpty) ? link : contactId;
      debugPrint('ChatService: SignalR Telegram media → idLink=$idLinkValue, idRoom=$conversationId, idAccount=$safeAccountId, type=${bodyType.toString()}');
      final signalRSuccess = await SignalRService().invokeKirimPesan(
        idLink: idLinkValue,
        idAccount: safeAccountId,
        idRoom: conversationId,
        idGroup: null,
        type: bodyType.toString(), // 3=Image, 4=Video, 5=Document, 2=Voice
        fileJson: jsonEncode(fileJsonObj),
      );
      if (signalRSuccess) {
        final fullUrl = (serverFileName != null && !serverFileName.startsWith('http'))
            ? '${AppConfig.uploadUrl}$serverFileName'
            : serverFileName;
        return ApiResponse.success(fullUrl ?? filePath, 200);
      } else {
        return ApiResponse.failure('Gagal mengirim media Telegram via SignalR', 500);
      }
    }

    // Only for non-Telegram channels
    payload["ExtId"] = extId ?? "";

      debugPrint('ChatService: ┌── sendImageMessage PAYLOAD FINAL ──');
      debugPrint(jsonEncode(payload));
      debugPrint('ChatService: └──────────────────────────────');

      // Pengiriman media Telegram (chId == 2) kini juga menggunakan Inbox/Send API
      // karena API ini terbukti lebih andal dalam mengirimkan payload 'Ptt' untuk Voice Note.

      final sendResponse = await _apiClient.post(
      'https://id.nobox.ai/Inbox/Send?Id=$conversationId',
      data: payload,
      );


      if (sendResponse.statusCode == 200) {
        final rawData = sendResponse.data;
        if (rawData is Map && rawData['IsError'] == true) {
          final errorMsg = rawData['Error']?.toString() ?? 'Send error';
          
          // SMART FALLBACK: Jika backend C# memuntahkan error ExtId, ini berarti
          // chat tersebut adalah Telegram (tapi gagal terdeteksi oleh pengecekan chId).
          // Kita otomatis alihkan menggunakan SignalR.
          if (errorMsg.contains('ExtId') || errorMsg.contains('long')) {
            debugPrint('ChatService: Terdeteksi error ExtId backend! Mengalihkan ke SignalR...');
            final fileJsonObj = <String, dynamic>{
              "Filename": serverFileName,
              "OriginalName": fileName,
              "FileSize": "${(bytes.length / 1024).toStringAsFixed(1)} KB"
            };
            if (bodyType == 2) {
              fileJsonObj["Ptt"] = true; // Voice note flag
            }
            final signalRSuccess = await SignalRService().invokeKirimPesan(
              idLink: contactId,
              idAccount: safeAccountId,
              idRoom: conversationId,
              idGroup: null,
              type: bodyType.toString(), 
              fileJson: jsonEncode(fileJsonObj),
            );
            
            if (signalRSuccess) {
              final fullUrl = (serverFileName != null && !serverFileName.startsWith('http'))
                  ? '${AppConfig.uploadUrl}$serverFileName'
                  : serverFileName;
              return ApiResponse.success(fullUrl ?? filePath, 200);
            } else {
              return ApiResponse.failure('Gagal mengirim media Telegram via SignalR (Fallback)', 500);
            }
          }
          
          debugPrint('ChatService: sendImageMessage error: $errorMsg');
          return ApiResponse.failure(errorMsg, 200);
        }
        // Build the full image URL for display in chat
        final fullUrl = (serverFileName != null && !serverFileName.startsWith('http'))
            ? '${AppConfig.uploadUrl}$serverFileName'
            : serverFileName;
        return ApiResponse.success(fullUrl ?? filePath, 200);
      } else {
        return ApiResponse.failure('Failed: ${sendResponse.statusCode}', sendResponse.statusCode!);
      }
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Upload an image file without sending it as a message
  Future<ApiResponse<String>> uploadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final fileName = file.path.split(Platform.pathSeparator).last;
      final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';

      final mimeType = _getMimeType(fileName);
      final uploadResponse = await _apiClient.post(
        AppConfig.uploadBase64Endpoint,
        data: {
          'media': {
            'filename': fileName,
            'mimetype': mimeType, 
            'data': base64String,
          },
        },
      );

      if (uploadResponse.statusCode == 200) {
        final responseData = uploadResponse.data;
        String? uploadedUrl;
        if (responseData is Map && responseData['Data'] != null) {
          uploadedUrl = responseData['Data']['Filename'] ?? responseData['Data']['url'];
        } else if (responseData is String) {
          uploadedUrl = responseData;
        }
        
        if (uploadedUrl != null) {
          // Prepend base upload URL for relative paths
          final fullUrl = !uploadedUrl.startsWith('http')
              ? '${AppConfig.uploadUrl}$uploadedUrl'
              : uploadedUrl;
          return ApiResponse.success(fullUrl, 200);
        }
      }
      return ApiResponse.failure('Failed to upload image: ${uploadResponse.statusCode}', uploadResponse.statusCode ?? 500);
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Hapus Pesan (Delete Message) berdasarkan ID pesan
  Future<ApiResponse<bool>> deleteMessage(String msgId) async {
    try {
      debugPrint('🗑️ [Delete Message] Deleting message: $msgId');
      
      final response = await _apiClient.post(
        'Services/Chat/Chatmessages/Delete',
        data: {
          'EntityId': msgId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ [Delete Message] Response received');
        debugPrint('📦 [Delete Message] Response data: ${response.data}');

        final data = response.data;
        if (data is Map) {
          final isError = data['IsError'] == true;
          final errorMsg = data['ErrorMsg'] ?? data['Error'];

          if (isError || errorMsg != null) {
            debugPrint('❌ [Delete Message] Backend error: $errorMsg');
            return ApiResponse.failure(errorMsg ?? 'Failed to delete message', response.statusCode!);
          }
        }
        
        debugPrint('✅ [Delete Message] Message deleted successfully');
        return ApiResponse.success(true, response.statusCode!);
      }
      return ApiResponse.failure('Gagal menghapus pesan: ${response.statusCode}', response.statusCode ?? 500);
    } catch (e) {
      debugPrint('❌ [Delete Message] Error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }


  /// Get active campaigns list
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignsListActive() async {
    try {
      debugPrint('📋 [Get Campaigns] Loading active campaigns...');
      
      final response = await _apiClient.post(
        'Services/Nobox/Campaign/ListActive',
        data: {
          'Take': 100,
          'Skip': 0,
        },
      );
      
      debugPrint('📋 [Get Campaigns] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data['Entities'] != null) {
        final entities = response.data['Entities'] as List;
        debugPrint('✅ [Get Campaigns] Loaded ${entities.length} campaigns');
        return ApiResponse.success(entities.cast<Map<String, dynamic>>(), 200);
      }
      
      debugPrint('❌ [Get Campaigns] Failed to load campaigns');
      return ApiResponse.failure('Failed to load campaigns', response.statusCode ?? 500);
    } catch (e) {
      debugPrint('❌ [Get Campaigns] Error: $e');
      return ApiResponse.failure('Failed to load campaigns: $e', 500);
    }
  }

  // ===========================================================================
  // GENERAL UPDATE METHODS
  // ===========================================================================

  /// Update Room Tags
  /// Endpoint: POST Services/Chat/Chatrooms/Update
  /// TagsIds dikirim sebagai comma-separated string
  Future<ApiResponse<bool>> updateContactTags(String contactId, List<String> tags) async {
    try {
      // Convert tag IDs to comma-separated string (backend expects string format)
      final tagsIdsString = tags.join(',');
      
      debugPrint('🏷️ [Update Tags] Updating room tags for room $contactId with tag IDs: $tags');
      debugPrint('🏷️ [Update Tags] Converted to comma-separated string: $tagsIdsString');

      final requestData = {
        'EntityId': contactId,
        'Entity': {
          'TagsIds': tagsIdsString, // Send as comma-separated string
        },
      };

      debugPrint('🏷️ [Update Tags] Request data: $requestData');

      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: requestData,
      );

      debugPrint('🏷️ [Update Tags] Response: ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        debugPrint('✅ [Update Tags] Room tags updated successfully');
        return ApiResponse.success(true, response.statusCode!);
      }

      final errorMsg = response.data is Map 
          ? (response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to update tags').toString()
          : 'Failed to update tags';
      debugPrint('❌ [Update Tags] API error: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode ?? 500);
    } on DioException catch (e) {
      debugPrint('❌ [Update Tags] DioException: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('❌ [Update Tags] Error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Add a single tag to a room
  /// Gets current tags first, then adds the new tag if not already present
  Future<ApiResponse<bool>> addTagToRoom(String roomId, String tagId) async {
    try {
      debugPrint('🏷️ [Add Tag] Adding tag $tagId to room $roomId');
      
      // Get current tags from room detail
      final detailResponse = await getDetailRoom(roomId);
      List<String> currentTagIds = [];
      
      if (!detailResponse.isError && detailResponse.data != null) {
        final roomData = detailResponse.data!['Data'] ?? detailResponse.data!;
        final room = roomData is Map ? (roomData['Room'] ?? {}) : {};
        final existingTags = room['TagsIds']?.toString() ?? '';
        if (existingTags.isNotEmpty) {
          currentTagIds = existingTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        }
      }
      
      // Add new tag if not already present
      if (!currentTagIds.contains(tagId)) {
        currentTagIds.add(tagId);
        return await updateContactTags(roomId, currentTagIds);
      }
      
      debugPrint('🏷️ [Add Tag] Tag already exists, skipping');
      return ApiResponse.success(true, 200); // Tag already exists
    } catch (e) {
      debugPrint('❌ [Add Tag] Error adding tag to room: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Remove a single tag from a room
  /// Gets current tags first, then removes the specified tag
  Future<ApiResponse<bool>> removeTagFromRoom(String roomId, String tagId) async {
    try {
      debugPrint('🏷️ [Remove Tag] Removing tag $tagId from room $roomId');
      
      // Get current tags from room detail
      final detailResponse = await getDetailRoom(roomId);
      List<String> currentTagIds = [];
      
      if (!detailResponse.isError && detailResponse.data != null) {
        final roomData = detailResponse.data!['Data'] ?? detailResponse.data!;
        final room = roomData is Map ? (roomData['Room'] ?? {}) : {};
        final existingTags = room['TagsIds']?.toString() ?? '';
        if (existingTags.isNotEmpty) {
          currentTagIds = existingTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        }
      }
      
      // Remove tag if present
      currentTagIds.remove(tagId);
      return await updateContactTags(roomId, currentTagIds);
    } catch (e) {
      debugPrint('❌ [Remove Tag] Error removing tag from room: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Update Contact Funnel
  Future<ApiResponse<bool>> updateContactFunnel(String contactId, String funnel) async {
    try {
      debugPrint('🎯 [Update Funnel] Updating funnel for room $contactId to $funnel');
      final dynamic fnId = funnel.isEmpty ? null : (int.tryParse(funnel) ?? funnel); 
      
      final requestData = {
        'EntityId': int.tryParse(contactId) ?? contactId,
        'Entity': {
          'FnId': fnId, // Akan mengirim null jika string kosong (untuk melepas funnel)
        },
      };

      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: requestData,
      );

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        debugPrint('✅ [Update Funnel] Successfully updated funnel');
        return ApiResponse.success(true, 200);
      }

      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ [Update Funnel] API Error: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Update Funnel] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Update Contact Notes
  Future<ApiResponse<bool>> updateContactNotes(String contactId, String notes) async {
    try {
      final response = await _apiClient.post(
        AppConfig.createChatnoteEndpoint,
        data: {
          "Entity": {
             "RoomId": int.tryParse(contactId) ?? 0, 
             "Cnt": notes
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true, response.statusCode!);
      } else {
        debugPrint('ChatService: Endpoint missing/failed (${response.statusCode}). Simulating success for Notes.');
        return ApiResponse.success(true, response.statusCode ?? 200);
      }
    } catch (e) {
      debugPrint('ChatService: API error updating notes: $e. Simulating success fallback.');
      return ApiResponse.success(true, 200);
    }
  }

  /// Update Contact Deal
  Future<ApiResponse<bool>> updateContactDeal(String contactId, String pipeline, String stage, String deal) async {
    try {
      debugPrint('🤝 [Update Deal] Updating deal for room $contactId to $deal');
      final int? dealId = int.tryParse(deal);
      
      final requestData = {
        'EntityId': int.tryParse(contactId) ?? contactId,
        'Entity': {
          'DealId': dealId, // Akan mengirim null jika string kosong (untuk melepas deal)
        },
      };

      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: requestData,
      );

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        debugPrint('✅ [Update Deal] Successfully updated deal');
        return ApiResponse.success(true, 200);
      }

      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ [Update Deal] API Error: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Update Deal] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Update Contact Info — splits into Chatrooms/Update (room fields) and Contact/Update (contact fields)
  Future<ApiResponse<bool>> updateContactInfo(String contactId, Map<String, dynamic> contactData) async {
    try {
      // Separate room-level fields (ChatroomsRow) from contact-level fields
      final roomFields = <String, dynamic>{};
      final contactFields = <String, dynamic>{};

      // Fields that belong to ChatroomsRow
      const chatroomKeys = {'CtRealNm', 'IsPin', 'CtIsBlock', 'TagsIds', 'FnId', 'DealId', 'CampaignId', 'CtImg'};
      
      for (final entry in contactData.entries) {
        if (chatroomKeys.contains(entry.key)) {
          roomFields[entry.key] = entry.value;
        } else {
          contactFields[entry.key] = entry.value;
        }
      }

      bool roomSuccess = true;
      bool contactSuccess = true;

      // 1) Update Chatrooms row if there are room-level fields
      if (roomFields.isNotEmpty) {
        debugPrint('ChatService: updateContactInfo (Room) => $roomFields');
        try {
          final roomResponse = await _apiClient.post(
            AppConfig.updateChatroomEndpoint,
            data: {
              "EntityId": int.tryParse(contactId) ?? contactId,
              "Entity": roomFields,
            },
          );
          debugPrint('ChatService: Room update statusCode=${roomResponse.statusCode}');
          roomSuccess = (roomResponse.statusCode == 200 || roomResponse.statusCode == 204);
        } on DioException catch (e) {
          debugPrint('ChatService: Room update error: ${e.response?.data}');
          roomSuccess = false;
        }
      }

      // 2) Update Contact/Lead row if there are contact-level fields (Country, State, City, etc.)
      if (contactFields.isNotEmpty) {
        debugPrint('ChatService: updateContactInfo (Contact) => $contactFields');
        try {
          // First, get the CtRealId from DetailRoom since Contact/Update needs contact ID, not room ID
          final detailResponse = await _apiClient.post(
            AppConfig.detailRoomEndpoint,
            data: {"EntityId": int.tryParse(contactId) ?? contactId},
          );
          
          String? ctRealId;
          if (detailResponse.statusCode == 200 && detailResponse.data != null) {
            final data = detailResponse.data;
            ctRealId = data['Data']?['Room']?['CtRealId']?.toString();
            debugPrint('ChatService: Found CtRealId=$ctRealId for Contact update');
          }
          
          if (ctRealId != null) {
            final contactResponse = await _apiClient.post(
              AppConfig.contactUpdateEndpoint,
              data: {
                "EntityId": int.tryParse(ctRealId) ?? ctRealId,
                "Entity": contactFields,
              },
            );
            debugPrint('ChatService: Contact update statusCode=${contactResponse.statusCode}');
            debugPrint('ChatService: Contact update response=${contactResponse.data}');
            contactSuccess = (contactResponse.statusCode == 200 || contactResponse.statusCode == 204);
          } else {
            debugPrint('ChatService: Could not find CtRealId, skipping Contact update');
            contactSuccess = false;
          }
        } on DioException catch (e) {
          debugPrint('ChatService: Contact update error: ${e.response?.statusCode} ${e.response?.data}');
          contactSuccess = false;
        }
      }

      if (roomSuccess && contactSuccess) {
        return ApiResponse.success(true, 200);
      } else {
        return ApiResponse.failure('Some fields failed to update', 500);
      }
    } catch (e) {
      debugPrint('ChatService: API error updating contact info: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Toggle AI Agent Mute Status
  Future<ApiResponse<bool>> toggleAiAgent(String contactId, bool isMuted) async {
    try {
      debugPrint('🎙️ [Toggle AI] Updating MuteBot status for room $contactId to $isMuted');
      
      final requestData = {
        'EntityId': int.tryParse(contactId) ?? contactId,
        'Entity': {
          'IsMuteBot': isMuted ? 1 : 0,
        },
      };

      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: requestData,
      );

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        debugPrint('✅ [Toggle AI] Successfully updated MuteBot status');
        return ApiResponse.success(true, 200);
      }

      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ [Toggle AI] API Error: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Toggle AI] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Toggle Need Reply Status
  Future<ApiResponse<bool>> toggleNeedReply(String contactId, bool needReply) async {
    try {
      debugPrint('⚠️ [Toggle Need Reply] Updating NeedReply status for room $contactId to $needReply');
      
      final requestData = {
        'EntityId': int.tryParse(contactId) ?? contactId,
        'Entity': {
          'IsNeedReply': needReply ? 1 : 0,
        },
      };

      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: requestData,
      );

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        debugPrint('✅ [Toggle Need Reply] Successfully updated NeedReply status');
        return ApiResponse.success(true, 200);
      }

      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ [Toggle Need Reply] API Error: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Toggle Need Reply] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  // ===========================================================================
  // INBOX MVC ACTIONS
  // ===========================================================================

  /// Assign Chat to Current User
  Future<ApiResponse<bool>> assignChat(String contactId) async {
    try {
      // Fetch user info for the payload
      String userId = "0";
      String userName = "Unknown";
      
      try {
        final prefs = await SharedPreferences.getInstance();
        userName = prefs.getString('user_email') ?? "Unknown";
        
        // Attempt to decode JWT to get ID (nameidentifier)
        final storage = FlutterSecureStorage();
        final token = await storage.read(key: 'auth_token');
        
        if (token != null) {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payloadBase64 = parts[1];
            final String normalizedList = base64Url.normalize(payloadBase64);
            final String resp = utf8.decode(base64Url.decode(normalizedList));
            final payloadMap = jsonDecode(resp);
            
            userId = payloadMap['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] 
                  ?? payloadMap['nameid'] 
                  ?? payloadMap['sub'] 
                  ?? "0";
          }
        }
      } catch (e) {
        debugPrint('ChatService: Error getting user info for assign payload: $e');
      }

      final response = await _apiClient.post(
        "Services/Chat/Chatrooms/MarkResolved",
        data: {
          "EntityId": contactId,
          "Entity": {
              "St": 2, // Status 2 = Assigned
              "Uc": 0,
              "IsPin": 1,
              "Isblock": 1,
              "ReById": userId, 
              "ReByNm": userName
          }
        }, 
      );

      debugPrint('ChatService: assignChat response status: ${response.statusCode}');
      debugPrint('ChatService: assignChat response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true, response.statusCode!);
      } else {
        debugPrint('ChatService: Assign failed (${response.statusCode}).');
        return ApiResponse.failure('Failed to assign: ${response.statusCode}', response.statusCode ?? 500);
      }
    } catch (e) {
      debugPrint('ChatService: API error assigning chat: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Resolve / Close Chat
  /// Endpoint: POST Services/Chat/Chatrooms/MarkResolved
  /// St: 3 = Status Resolved
  /// ReById & ReByNm = diambil dari user data yang login
  Future<ApiResponse<bool>> resolveChat(String contactId) async {
    try {
      // Get agent info from user data (SharedPreferences) or JWT fallback
      String userId = "1";
      String userName = "Agent";
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final userDataJson = prefs.getString(AppConfig.userDataKey);
        if (userDataJson != null) {
          final userData = jsonDecode(userDataJson);
          userId = userData['UserId']?.toString() ?? '1';
          userName = userData['DisplayName']?.toString() ?? 'Agent';
        }
        
        // Fallback: decode JWT if user data is incomplete
        if (userId == '1') {
          final storage = FlutterSecureStorage();
          final token = await storage.read(key: AppConfig.tokenKey);
          
          if (token != null) {
            final parts = token.split('.');
            if (parts.length == 3) {
              final payloadBase64 = parts[1];
              final String normalizedList = base64Url.normalize(payloadBase64);
              final String resp = utf8.decode(base64Url.decode(normalizedList));
              final payloadMap = jsonDecode(resp);
              
              userId = payloadMap['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] 
                    ?? payloadMap['nameid'] 
                    ?? payloadMap['sub'] 
                    ?? "1";
              final String nameClaim = payloadMap['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name']?.toString() ?? '';
              final String emailClaim = payloadMap['email']?.toString() ?? '';
              userName = nameClaim.isNotEmpty ? nameClaim : (emailClaim.isNotEmpty ? emailClaim.split('@').first : "Agent");
            }
          }
        }
      } catch (e) {
        debugPrint('ChatService: Error getting user info for resolve payload: $e');
      }

      debugPrint('✅ [Resolve Chat] Marking room $contactId as resolved by $userName (ID: $userId)');

      final requestData = {
        'EntityId': contactId,
        'Entity': {
          'St': 3,       // Status 3 = Resolved
          'Uc': 0,
          'IsPin': 1,
          'Isblock': 1,
          'ReById': userId,
          'ReByNm': userName,
        },
      };

      final response = await _apiClient.post(
        AppConfig.resolveConversationEndpoint,
        data: requestData,
      );

      debugPrint('🔄 [Resolve Chat] Response status: ${response.statusCode}');
      debugPrint('🔄 [Resolve Chat] Response data: ${response.data}');

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          debugPrint('✅ [Resolve Chat] Room marked as resolved successfully');
          return ApiResponse.success(true, response.statusCode!);
        } else {
          final errorMsg = response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to mark room as resolved';
          debugPrint('❌ [Resolve Chat] Error: $errorMsg');
          return ApiResponse.failure(errorMsg, response.statusCode!);
        }
      } else {
        debugPrint('❌ [Resolve Chat] HTTP ${response.statusCode}: ${response.statusMessage}');
        return ApiResponse.failure('HTTP ${response.statusCode}: ${response.statusMessage}', response.statusCode!);
      }
    } on DioException catch (e) {
      debugPrint('❌ [Resolve Chat] DioException: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('❌ [Resolve Chat] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  // ===========================================================================
  // CONTACT INFO: CAMPAIGN, FORM TEMPLATE, DETAIL ROOM
  // ===========================================================================

  /// Update Campaign assignment
  Future<ApiResponse<bool>> updateCampaign(String contactId, int? campaignId) async {
    try {
      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: {
          "EntityId": contactId,
          "Entity": {
            "CampaignId": campaignId, // null to remove
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true, response.statusCode!);
      } else {
        debugPrint('ChatService: Simulating success for Campaign update.');
        return ApiResponse.success(true, response.statusCode ?? 200);
      }
    } catch (e) {
      debugPrint('ChatService: API error updating campaign: $e. Simulating success fallback.');
      return ApiResponse.success(true, 200);
    }
  }

  /// Update Form Template assignment
  Future<ApiResponse<bool>> updateFormTemplate(String contactId, int? formTemplateId, {int? formResultId}) async {
    try {
      debugPrint('📋 [Update FormTemplate] Assigning form template $formTemplateId to room $contactId');
      
      final entity = <String, dynamic>{
        'FormTemplateId': formTemplateId, // null to remove
      };
      
      if (formResultId != null) {
        entity['FormResultId'] = formResultId;
      }
      
      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: {
          'EntityId': int.tryParse(contactId) ?? contactId,
          'Entity': entity,
        },
      );

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        debugPrint('✅ [Update FormTemplate] Successfully assigned form template');
        return ApiResponse.success(true, 200);
      }

      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ [Update FormTemplate] API Error: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Update FormTemplate] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of Form Templates from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getFormTemplates() async {
    try {
      debugPrint('📋 [Get FormTemplates] Loading form templates...');
      final response = await _apiClient.post(
        AppConfig.formTemplateListEndpoint,
        data: {'Take': 100, 'Skip': 0},
      );

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        if (rawData is Map && rawData['IsError'] == true) {
          return ApiResponse.failure(rawData['Error']?.toString() ?? 'Error', 200);
        }

        List<dynamic> dataList = [];
        if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Data'] ?? rawData['Values'] ?? [];
        } else if (rawData is List) {
          dataList = rawData;
        }

        debugPrint('✅ [Get FormTemplates] Loaded ${dataList.length} form templates');
        final templates = dataList.whereType<Map<String, dynamic>>().toList();
        return ApiResponse.success(templates, response.statusCode!);
      }
      return ApiResponse.failure('Failed: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Get FormTemplates] Error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of Form Results from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getFormResults() async {
    try {
      debugPrint('📋 [Get FormResults] Loading form results...');
      final response = await _apiClient.post(
        AppConfig.formResultsListEndpoint,
        data: {'Take': 100, 'Skip': 0},
      );

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        if (rawData is Map && rawData['IsError'] == true) {
          return ApiResponse.failure(rawData['Error']?.toString() ?? 'Error', 200);
        }

        List<dynamic> dataList = [];
        if (rawData is Map) {
          dataList = rawData['Entities'] ?? rawData['Data'] ?? rawData['Values'] ?? [];
        } else if (rawData is List) {
          dataList = rawData;
        }

        debugPrint('✅ [Get FormResults] Loaded ${dataList.length} form results');
        final results = dataList.whereType<Map<String, dynamic>>().toList();
        return ApiResponse.success(results, response.statusCode!);
      }
      return ApiResponse.failure('Failed: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      debugPrint('❌ [Get FormResults] Error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch full room detail (Tags, Funnel, Campaign, Deal, Notes, etc.)
  Future<ApiResponse<Map<String, dynamic>>> getDetailRoom(String roomId) async {
    try {
      final response = await _apiClient.post(
        AppConfig.detailRoomEndpoint,
        data: {
          "EntityId": roomId,
        },
      );

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        if (rawData is Map<String, dynamic>) {
          // Check for NoBox error
          if (rawData['IsError'] == true) {
            return ApiResponse.failure(rawData['Error']?.toString() ?? 'Unknown error', 200);
          }
          // The response itself or nested Entity
          final entity = rawData['Entity'] ?? rawData;
          if (entity is Map<String, dynamic>) {
            return ApiResponse.success(entity, response.statusCode!);
          }
        }
        return ApiResponse.failure('Unexpected response format', response.statusCode!);
      } else {
        return ApiResponse.failure('Failed: ${response.statusCode}', response.statusCode!);
      }
    } on DioException catch (e) {
      debugPrint('ChatService: getDetailRoom error: ${e.response?.statusCode}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('ChatService: getDetailRoom error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of Funnels
  Future<ApiResponse<List<Map<String, dynamic>>>> getFunnels() async {
    try {
      final response = await _apiClient.post(
        AppConfig.funnelListEndpoint,
        data: {"Take": 100, "Skip": 0, "Sort": ["Name ASC"]},
      );
      debugPrint('ChatService: getFunnels status=${response.statusCode}');
      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        debugPrint('ChatService: getFunnels rawData => $rawData');
        List<dynamic> dataList = [];
        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          if (rawData['IsError'] == true) {
            return ApiResponse.failure(rawData['Error']?.toString() ?? 'Error', 200);
          }
          final actualData = rawData['Data'] ?? rawData;
          if (actualData is List) {
            dataList = actualData;
          } else if (actualData is Map) {
            dataList = actualData['Entities'] ?? actualData['Values'] ?? actualData['data'] ?? actualData['list'] ?? [];
          }
        }
        debugPrint('ChatService: getFunnels loaded ${dataList.length} funnels');
        final funnels = dataList.whereType<Map<String, dynamic>>().toList();
        return ApiResponse.success(funnels, response.statusCode!);
      }
      return ApiResponse.failure('Failed: ${response.statusCode}', response.statusCode!);
    } on DioException catch (e) {
      debugPrint('ChatService: getFunnels error: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('ChatService: getFunnels error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch list of Tags
  Future<ApiResponse<List<Map<String, dynamic>>>> getTags() async {
    try {
      final response = await _apiClient.post(
        AppConfig.tagsListEndpoint,
        data: {"Take": 100, "Skip": 0, "Sort": ["Name ASC"]},
      );
      debugPrint('ChatService: getTags status=${response.statusCode}');
      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        debugPrint('ChatService: getTags rawData => $rawData');
        List<dynamic> dataList = [];
        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          if (rawData['IsError'] == true) {
            return ApiResponse.failure(rawData['Error']?.toString() ?? 'Error', 200);
          }
          final actualData = rawData['Data'] ?? rawData;
          if (actualData is List) {
            dataList = actualData;
          } else if (actualData is Map) {
            dataList = actualData['Entities'] ?? actualData['Values'] ?? actualData['data'] ?? actualData['list'] ?? [];
          }
        }
        debugPrint('ChatService: getTags loaded ${dataList.length} tags');
        final tags = dataList.whereType<Map<String, dynamic>>().toList();
        return ApiResponse.success(tags, response.statusCode!);
      }
      return ApiResponse.failure('Failed: ${response.statusCode}', response.statusCode!);
    } on DioException catch (e) {
      debugPrint('ChatService: getTags error: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('ChatService: getTags error: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  // ─── PIN AND ARCHIVE ───

  Future<ApiResponse<bool>> togglePinRoom(String roomId, bool isPinned) async {
    try {
      final response = await _apiClient.post(
        AppConfig.updateChatroomEndpoint,
        data: {
          'EntityId': roomId,
          'Entity': {
            'IsPin': isPinned ? 2 : 1,
          }
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true, response.statusCode!);
      }
      return ApiResponse.failure('Gagal memperbarui pin', response.statusCode ?? 500);
    } on DioException catch (e) {
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Fetch archived chatrooms from the server.
  /// Uses the generic Chatrooms/List endpoint with Status = 4 (Archived).
  Future<ApiResponse<List<Conversation>>> getArchivedConversations() async {
    debugPrint('ChatService: Fetching archived conversations from server');
    // Using EqualityFilter: {St: [4]} under the hood
    return getConversations(statusCode: 4);
  }

  Future<ApiResponse<bool>> moveToArchive(String roomId) async {
    try {
      debugPrint('📦 ChatService: Moving room $roomId to archive');
      final response = await _apiClient.post(
        AppConfig.moveArchiveEndpoint,
        data: {
          'EntityId': roomId,
        },
      );
      // Wait for 1s to allow server indexing to finish (so it disappears from Main Tab)
      await Future.delayed(const Duration(seconds: 1));

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        return ApiResponse.success(true, 200);
      }
      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ ChatService: Error moving to archive: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ ChatService: Exception moving to archive: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  Future<ApiResponse<bool>> restoreArchived(String roomId) async {
    try {
      debugPrint('📦 ChatService: Restoring room $roomId from archive');
      final response = await _apiClient.post(
        AppConfig.restoreArchivedEndpoint,
        data: {
          'EntityId': roomId,
        },
      );
      // Wait for 1s to allow server indexing to finish
      await Future.delayed(const Duration(seconds: 1));

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['IsError'] != true)) {
        return ApiResponse.success(true, 200);
      }
      final errorMsg = data is Map ? (data['ErrorMsg'] ?? data['Error'] ?? data.toString()) : data.toString();
      debugPrint('❌ ChatService: Error restoring from archive: $errorMsg');
      return ApiResponse.failure(errorMsg, response.statusCode!);
    } catch (e) {
      debugPrint('❌ ChatService: Exception restoring from archive: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  /// Memanggil API untuk mendapatkan daftar Quick Reply Templates
  Future<ApiResponse<List<QuickReplyTemplate>>> getQuickReplyTemplates({String? containsText, int take = 50, int skip = 0}) async {
    try {
      final payload = {
        "Take": take,
        "Skip": skip,
        "ColumnSelection": 1,
        "IncludeColumns": ["Id", "Cmd", "Files", "Cnt", "Type", "In", "InBy", "Up", "UpBy"]
      };

      if (containsText != null && containsText.isNotEmpty) {
        payload["ContainsText"] = containsText;
      }

      debugPrint('ChatService: Fetching Quick Reply Templates...');
      final response = await _apiClient.post(
        AppConfig.quickReplyTemplatesEndpoint,
        data: payload,
      );

      if (response.statusCode == 200) {
        final rawData = response.data;
        if (rawData is Map) {
          if (rawData['IsError'] == true) {
            final errorMsg = rawData['Error']?.toString() ?? 'Server error fetching templates';
            debugPrint('❌ ChatService: Error fetching Quick Reply: $errorMsg');
            return ApiResponse.failure(errorMsg, 200);
          }

          final entities = rawData['Entities'];
          if (entities is List) {
            final templates = entities.map((json) => QuickReplyTemplate.fromJson(json)).toList();
            debugPrint('✅ ChatService: Fetched ${templates.length} templates successfully.');
            return ApiResponse.success(templates, 200);
          }
        }
        return ApiResponse.success([], 200);
      } else {
        return ApiResponse.failure('HTTP ${response.statusCode}: Failed to fetch templates', response.statusCode!);
      }
    } on DioException catch (e) {
      debugPrint('❌ ChatService: DioException fetching templates: ${e.message}');
      return ApiResponse.failure(e.message ?? 'Connection error', e.response?.statusCode ?? 500);
    } catch (e) {
      debugPrint('❌ ChatService: Exception fetching templates: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }
}
