import 'message.dart';

// =====================================================================
// FITUR: Model Percakapan (Conversation/Chatroom)
// FILE: lib/core/model/conversation.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class model untuk menampung data list chat/room di halaman utama chat
// =====================================================================
class Conversation {

  final String id;
  final String contactId; // CtId dari Chatrooms/List — dibutuhkan untuk Inbox/Send dan Inbox/Get
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
  final String channelType;
  final bool isPinned;
  final String chId;
  final String funnel;
  final String tagsIds;
  final String funnelId;
  final bool isGroup;
  final bool isBlocked;
  final bool isLastMessageFromMe;
  final bool needReply;
  final String accountId;
  final String ctRealId;
  final String link;
  final String campaign;
  final String deal;
  final String groupName;
  final String groupId;

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
    this.channelType = '',
    this.isPinned = false,
    this.chId = '',
    this.funnel = '',
    this.tagsIds = '',
    this.funnelId = '',
    this.isGroup = false,
    this.isBlocked = false,
    this.isLastMessageFromMe = false,
    this.needReply = false,
    this.accountId = '',
    this.ctRealId = '',
    this.link = '',
    this.campaign = '',
    this.deal = '',
    this.groupName = '',
    this.groupId = '',
  });

  // FITUR: Parse dari JSON
  // FUNGSI: Mengubah response JSON list chat API menjadi objek Conversation
  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Parse tags dari JSON - Menangani tipe dinamis dengan aman (int, String, List)
    List<String> parsedTags = [];
    dynamic tagsData = json['Tags'] ?? json['tags'] ?? json['TagsNm'];
    if (tagsData != null) {
      if (tagsData is List) {
        parsedTags = tagsData.map((e) => e.toString()).toList();
      } else if (tagsData is String && tagsData.isNotEmpty) {
        parsedTags = tagsData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (tagsData is int || tagsData is double) {
        parsedTags = [tagsData.toString()];
      }
    }
    // Kita secara eksplisit menghindari fallback ke TagsIds karena hanya berisi angka ID mentah, bukan nama.

    // Map St (integer) dari Chatrooms/List → string status yang bisa dibaca manusia
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

    // Helper pencarian (lookup) tidak peka huruf besar/kecil (Case-insensitive)
    dynamic getValue(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null) return json[k];
      }
      return null;
    }

    // Coba beberapa kemungkinan nama kunci (key) untuk Tags dan Funnel IDs berdasarkan format backend
    // Parse TagsIds dengan aman karena nilainya bisa berupa int, String, atau List
    dynamic rawTagsIdsData = getValue(['TagsIds', 'tags_ids', 'tagsIds']);
    String rawTagsIds = '';
    if (rawTagsIdsData is List) {
      rawTagsIds = rawTagsIdsData.map((e) => e.toString()).join(',');
    } else if (rawTagsIdsData != null) {
      rawTagsIds = rawTagsIdsData.toString();
    }
    final rawFnId = getValue(['FnId', 'fn_id', 'fnId', 'FunnelId'])?.toString() ?? '';
    final rawFnName = getValue(['FnNm', 'fn_nm', 'Fn', 'fn'])?.toString() ?? '';

    final conv = Conversation(
      id: getValue(['Id', 'id'])?.toString() ?? '',
      contactId: getValue(['CtId', 'ContactId', 'GrpId', 'Id', 'id'])?.toString() ?? '',
      participantEmail: getValue(['CtRealNm', 'CtNm', 'Nm', 'nm', 'Ct', 'Grp', 'Name', 'participant_email', 'GroupNm', 'GroupName', 'group_name', 'Title', 'pushName'])?.toString() ?? 'Unknown',
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
      channelType: getValue(['ChNm', 'ChannelName', 'chnm'])?.toString() ?? '',
      isPinned: json['IsPin'] == 2 || json['is_pinned'] == true,
      chId: getValue(['ChId', 'ch_id'])?.toString() ?? '',
      accountId: getValue(['AccId', 'acc_id', 'AccountId', 'accountId'])?.toString() ?? '',
      funnel: rawFnName,
      tagsIds: rawTagsIds,
      funnelId: rawFnId,
      isGroup: (json['IsGrp']?.toString() == '1') || 
               (json['IsGrp'] == 1) || 
               (json['IsGrp'] == true) || 
               (json['IsGroup'] == true) || 
               (json['is_group'] == true) || 
               (json['isGroup'] == true) || 
               (json['GrpId'] != null && json['GrpId'].toString().isNotEmpty && json['GrpId'].toString() != '0') || 
               ((getValue(['CtRealId', 'ct_real_id', 'CtId', 'ContactId', 'Id', 'id'])?.toString() ?? '').endsWith('@g.us')) ||
               ((getValue(['CtRealNm', 'CtNm', 'Nm', 'nm', 'Ct', 'Grp', 'Name', 'participant_email'])?.toString() ?? '').toUpperCase().contains('GROUP')) ||
               ((getValue(['CtRealNm', 'CtNm', 'Nm', 'nm', 'Ct', 'Grp', 'Name', 'participant_email'])?.toString() ?? '').toUpperCase().contains('GRUP')) ||
               ((getValue(['GroupNm', 'GroupName', 'group_name'])?.toString() ?? '').isNotEmpty) ||
               ((getValue(['ChatType', 'chat_type', 'Type', 'type'])?.toString() ?? '').toLowerCase() == 'group'),
      isBlocked: json['CtIsBlock'] == 1 || json['CtIsBlock'] == true,
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
      ctRealId: getValue(['CtRealId', 'ct_real_id'])?.toString() ?? '',
      link: getValue(['LinkTmp', 'LinkNm', 'LinkName', 'link_name', 'Link'])?.toString() ?? '',
      campaign: getValue(['CmpNm', 'CampaignNm', 'CampaignName', 'campaign_name', 'Campaign'])?.toString() ?? '',
      deal: getValue(['DealNm', 'DealName', 'deal_name', 'Deal'])?.toString() ?? '',
      groupName: getValue(['Grp', 'GroupNm', 'GroupName', 'group_name'])?.toString() ?? '',
      groupId: getValue(['GrpId', 'group_id'])?.toString() ?? '',
    );

    return conv;
  }

  // FITUR: Copy With (Duplikasi Object)
  // FUNGSI: Mengganti sebagian property dari object yang sudah ada tanpa merubah aslinya
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
    String? channelType,
    bool? isPinned,
    String? chId,
    String? funnel,
    String? tagsIds,
    String? funnelId,
    // FIX: isGroup harus ikut di-copy, supaya tidak ter-reset ke false
    bool? isGroup,
    bool? isBlocked,
    bool? isLastMessageFromMe,
    bool? needReply,
    String? accountId,
    String? ctRealId,
    String? groupId,
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
      channelType: channelType ?? this.channelType,
      isPinned: isPinned ?? this.isPinned,
      chId: chId ?? this.chId,
      funnel: funnel ?? this.funnel,
      tagsIds: tagsIds ?? this.tagsIds,
      funnelId: funnelId ?? this.funnelId,
      // FIX: Pastikan isGroup ikut dipertahankan saat copyWith dipanggil
      isGroup: isGroup ?? this.isGroup,
      isBlocked: isBlocked ?? this.isBlocked,
      isLastMessageFromMe: isLastMessageFromMe ?? this.isLastMessageFromMe,
      needReply: needReply ?? this.needReply,
      accountId: accountId ?? this.accountId,
      ctRealId: ctRealId ?? this.ctRealId,
      groupId: groupId ?? this.groupId,
    );
  }

  // FITUR: Resolve Avatar URL
  // FUNGSI: Menentukan sumber gambar profile (Avatar) prioritas tertinggi dari JSON
  static String? _resolveAvatarUrl(Map<String, dynamic> json) {
    // Coba beberapa field sumber avatar sesuai urutan prioritas.
    // PENTING: Kita harus mengecek satu per satu karena ?.toString() pada string
    // kosong "" mengembalikan "" (bukan null), yang akan memblokir fallback ?? 
    // dan mencegah penggunaan field selanjutnya seperti LinkImg.
    final candidates = [
      json['CtImg'],      // Diatur setelah Contact/Update
      json['LinkImg'],    // Foto profil dari Instagram/Tokopedia/dll
      json['AvatarUrl'],
      json['avatar_url'],
    ];

    String? raw;
    for (final val in candidates) {
      if (val == null) continue;
      final str = val.toString().trim();
      if (str.isNotEmpty && str != 'null') {
        final lowerStr = str.toLowerCase();
        if (lowerStr.contains('default') || lowerStr.contains('error:') || str.contains('{')) continue;
        raw = str;
        break;
      }
    }

    if (raw == null) return null;
    // Jika sudah berupa URL penuh, gunakan apa adanya
    if (raw.startsWith('http')) return raw;
    // Tambahkan awalan base upload URL untuk path relatif
    return 'https://id.nobox.ai/upload/$raw';
  }

  // FITUR: Resolve Channel Name
  // FUNGSI: Menentukan nama channel yang dipakai (WhatsApp, IG, dll)
  static String _resolveChannelName(Map<String, dynamic> json) {
    final candidates = [
      json['AccNm'], json['ChNm'], json['ChAcc'], json['ChannelAccount'],
      json['accountName'], json['AccountName'], json['account_name']
    ];
    for (final val in candidates) {
      if (val != null && val.toString().isNotEmpty && val.toString() != 'Not Found') {
        return val.toString();
      }
    }
    return '';
  }

  // FITUR: Konversi ke ChatModel
  // FUNGSI: Mapping dari tipe Conversation (API Nobox) ke tipe ChatModel (UI Presentation)
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
      channelType: channelType,
      isPinned: isPinned,
      chId: chId,
      funnel: funnel,
      isGroup: isGroup,
      isBlocked: isBlocked,
      isLastMessageFromMe: isLastMessageFromMe,
      needReply: needReply,
      accountId: accountId,
      ctRealId: ctRealId,
      link: link,
      campaign: campaign,
      deal: deal,
      groupName: groupName,
      groupId: groupId,
    );
  }
}
