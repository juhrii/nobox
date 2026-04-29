import 'message.dart';

class Conversation {

  final String id;
  final String contactId; // CtId from Chatrooms/List — needed for Inbox/Send and Inbox/Get
  final String participantEmail;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final String status;
  final String agentName;
  final List<String> tags;
  final String? avatarUrl;
  final String? lastMessageType;
  final String channelName;
  final bool isPinned;
  final String chId;
  final String funnel;
  final String tagsIds;
  final String funnelId;
  final bool isGroup;
  final bool isLastMessageFromMe;
  final bool needReply;
  final String accountId;

  Conversation({
    required this.id,
    this.contactId = '',
    required this.participantEmail,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.status = 'Unassigned',
    this.agentName = '',
    this.tags = const [],
    this.avatarUrl,
    this.lastMessageType,
    this.channelName = '',
    this.isPinned = false,
    this.chId = '',
    this.funnel = '',
    this.tagsIds = '',
    this.funnelId = '',
    this.isGroup = false,
    this.isLastMessageFromMe = false,
    this.needReply = false,
    this.accountId = '',
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Parse tags from JSON - Prioritize name fields over ID fields
    List<String> parsedTags = [];
    if (json['Tags'] != null && json['Tags'] is List && (json['Tags'] as List).isNotEmpty) {
      parsedTags = (json['Tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] != null && json['tags'] is List && (json['tags'] as List).isNotEmpty) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['TagsNm'] != null && json['TagsNm'].toString().isNotEmpty) {
      parsedTags = json['TagsNm'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (json['Tags'] != null && json['Tags'] is String && json['Tags'].toString().isNotEmpty) {
      // Tags from Chatrooms/List often come as a comma-separated string containing names
      parsedTags = json['Tags'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    // We explicitly avoid falling back to TagsIds because it only contains raw ID numbers, not names.

    // Map St (integer) from Chatrooms/List → human-readable status string
    // 1 = Unassigned, 2 = Assigned, 3 = Resolved
    String resolveStatus(dynamic stValue) {
      final st = stValue is int ? stValue : int.tryParse(stValue?.toString() ?? '');
      switch (st) {
        case 1: return 'Unassigned';
        case 2: return 'Assigned';
        case 3: return 'Resolved';
        default: return 'Unassigned';
      }
    }

    // Case-insensitive lookup helper
    dynamic getValue(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null) return json[k];
      }
      return null;
    }

    // Try multiple possible key names for Tags and Funnel IDs based on backend quirks
    final rawTagsIds = getValue(['TagsIds', 'tags_ids', 'tagsIds'])?.toString() ?? '';
    final rawFnId = getValue(['FnId', 'fn_id', 'fnId', 'FunnelId'])?.toString() ?? '';
    final rawFnName = getValue(['FnNm', 'fn_nm', 'Fn', 'fn'])?.toString() ?? '';

    final conv = Conversation(
      id: getValue(['Id', 'id'])?.toString() ?? '',
      contactId: getValue(['CtId', 'ContactId', 'Id', 'id'])?.toString() ?? '',
      participantEmail: getValue(['CtRealNm', 'Ct', 'Grp', 'Name', 'participant_email']) ?? 'Unknown',
      lastMessage: getValue(['LastMsg', 'Category', 'last_message']) ?? '',
      lastMessageTime: getValue(['TimeMsg', 'In', 'last_message_time']) ?? '',
      unreadCount: getValue(['Uc', 'unread_count', 'UnreadCount']) ?? 0,
      status: json['St'] != null
          ? resolveStatus(json['St'])
          : (getValue(['Status', 'status']) ?? 'Unassigned'),
      agentName: getValue(['AssignedAgentName', 'AgentName', 'agent_name']) ?? '',
      tags: parsedTags,
      avatarUrl: _resolveAvatarUrl(json),
      lastMessageType: getValue(['LastMessageType', 'last_message_type']),
      channelName: _resolveChannelName(json),
      isPinned: json['IsPin'] == 2 || json['is_pinned'] == true,
      chId: getValue(['ChId', 'ch_id'])?.toString() ?? '',
      accountId: getValue(['AccId', 'acc_id', 'AccountId', 'accountId'])?.toString() ?? '',
      funnel: rawFnName,
      tagsIds: rawTagsIds,
      funnelId: rawFnId,
      isGroup: (json['IsGrp']?.toString() == '1') || 
               (json['IsGrp'] == 1) || 
               (json['IsGroup'] == true) || 
               (json['GrpId'] != null) || 
               (json['Grp'] != null),
      isLastMessageFromMe: json['IsMe'] == true ||
          json['LastIsMe'] == true ||
          json['AgentId'] != null ||
          getValue(['is_last_message_from_me', 'IsMeLast']) == true,
      needReply: json['NeedReply'] == 1 || 
          json['NeedReply'] == true || 
          json['IsNeedReply'] == 1 || 
          json['IsNeedReply'] == true ||
          json['isNeedReply'] == 1 ||
          json['isNeedReply'] == true,
    );

    return conv;
  }

  Conversation copyWith({
    String? id,
    String? contactId,
    String? participantEmail,
    String? lastMessage,
    String? lastMessageTime,
    int? unreadCount,
    String? status,
    String? agentName,
    List<String>? tags,
    String? avatarUrl,
    String? lastMessageType,
    String? channelName,
    bool? isPinned,
    String? chId,
    String? funnel,
    String? tagsIds,
    String? funnelId,
    // FIX: isGroup harus ikut di-copy, supaya tidak ter-reset ke false
    bool? isGroup,
    bool? isLastMessageFromMe,
    bool? needReply,
    String? accountId,
  }) {
    return Conversation(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      participantEmail: participantEmail ?? this.participantEmail,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      status: status ?? this.status,
      agentName: agentName ?? this.agentName,
      tags: tags ?? this.tags,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      channelName: channelName ?? this.channelName,
      isPinned: isPinned ?? this.isPinned,
      chId: chId ?? this.chId,
      funnel: funnel ?? this.funnel,
      tagsIds: tagsIds ?? this.tagsIds,
      funnelId: funnelId ?? this.funnelId,
      // FIX: Pastikan isGroup ikut dipertahankan saat copyWith dipanggil
      isGroup: isGroup ?? this.isGroup,
      isLastMessageFromMe: isLastMessageFromMe ?? this.isLastMessageFromMe,
      needReply: needReply ?? this.needReply,
      accountId: accountId ?? this.accountId,
    );
  }

  static String? _resolveAvatarUrl(Map<String, dynamic> json) {
    // Try CtImg first (set after Contact/Update), then LinkImg, then AvatarUrl
    final raw = json['CtImg']?.toString() ??
        json['LinkImg']?.toString() ??
        json['AvatarUrl']?.toString() ??
        json['avatar_url']?.toString();
    if (raw == null || raw.isEmpty) return null;
    // If already a full URL, use as-is
    if (raw.startsWith('http')) return raw;
    // Prepend base upload URL for relative paths
    return 'https://id.nobox.ai/upload/$raw';
  }

  static String _resolveChannelName(Map<String, dynamic> json) {
    final candidates = [
      json['AccNm'], json['ChNm'], json['ChAcc'], json['ChannelAccount'],
    ];
    for (final val in candidates) {
      if (val != null && val.toString().isNotEmpty && val.toString() != 'Not Found') {
        return val.toString();
      }
    }
    return '';
  }

  ChatModel toChatModel() {
    return ChatModel(
      id: id,
      contactId: contactId,
      sender: participantEmail,
      lastMessage: lastMessage,
      time: lastMessageTime,
      unreadCount: unreadCount,
      status: status,
      agentName: agentName,
      tags: tags,
      avatarUrl: avatarUrl,
      lastMessageType: lastMessageType,
      channelName: channelName,
      isPinned: isPinned,
      chId: chId,
      funnel: funnel,
      isGroup: isGroup,
      isLastMessageFromMe: isLastMessageFromMe,
      needReply: needReply,
      accountId: accountId,
    );
  }
}
