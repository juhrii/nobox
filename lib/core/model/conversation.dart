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

    // FIX: Prioritaskan payload JSON (yang biasanya ada di Category atau LastMsg) 
    // agar media (Voice Note, Photo) tidak berubah menjadi sekadar "Document" saat refresh
    String resolveLastMessage(dynamic lastMsgData, dynamic categoryData) {
      final str1 = lastMsgData?.toString() ?? '';
      final str2 = categoryData?.toString() ?? '';
      if (str1.startsWith('{') || str1.startsWith('[')) return str1;
      if (str2.startsWith('{') || str2.startsWith('[')) return str2;
      return str1.isNotEmpty ? str1 : str2;
    }

    final finalLastMessage = resolveLastMessage(
      getValue(['LastMsg', 'last_message']),
      getValue(['Category'])
    );

    // FIX: Server NoBox sering nyangkut di LastMessageType = 2 (Voice Note) atau media lain,
    // padahal LastMsg sudah update menjadi teks biasa. 
    // Bersihkan LastMessageType jika pesannya jelas bukan JSON.
    String? rawLastMessageType = getValue(['LastMessageType', 'last_message_type'])?.toString();
    if (!finalLastMessage.startsWith('{') && !finalLastMessage.startsWith('[')) {
      final lower = finalLastMessage.trim().toLowerCase();
      if (lower.isNotEmpty && lower != 'document(empty)' && lower != 'voice(empty)') {
        if (rawLastMessageType == '2' || rawLastMessageType == '3' || rawLastMessageType == '4' || rawLastMessageType == '5') {
          rawLastMessageType = '1';
        }
      }
    }

    // Helper untuk mendeteksi apakah obrolan benar-benar Group atau Private (individu)
    bool resolveIsGroup() {
      // 1. Cek JID WhatsApp secara eksplisit (@g.us = Group, @s.whatsapp.net / @c.us = Private)
      final contactStr = (getValue(['CtRealId', 'ct_real_id', 'CtId', 'ContactId', 'Id', 'id', 'LinkTmp', 'Link'])?.toString() ?? '').trim().toLowerCase();
      if (contactStr.contains('@g.us') || contactStr.contains('-') && contactStr.endsWith('@g.us')) return true;
      if (contactStr.contains('@s.whatsapp.net') || contactStr.contains('@c.us') || contactStr.contains('@lid')) return false;

      // 2. Cek flag boolean/integer eksplisit dari server (IsGrp, IsGroup, is_group, isGroup)
      final grpFlag = getValue(['IsGrp', 'IsGroup', 'is_group', 'isGroup']);
      if (grpFlag != null && grpFlag.toString().isNotEmpty && grpFlag.toString() != 'null') {
        final strFlag = grpFlag.toString().trim().toLowerCase();
        if (strFlag == '1' || strFlag == 'true') return true;
        if (strFlag == '0' || strFlag == 'false') return false;
      }

      // 3. Cek tipe obrolan secara eksplisit (ChatType / type)
      final chatType = (getValue(['ChatType', 'chat_type', 'Type', 'type'])?.toString() ?? '').trim().toLowerCase();
      if (chatType == 'group' || chatType == 'grup' || chatType == 'groupchat') return true;
      if (chatType == 'private' || chatType == 'personal' || chatType == 'user' || chatType == 'contact' || chatType == 'direct') return false;

      // 4. Jika tidak terdeteksi penanda grup WhatsApp yang spesifik, maka dipaksa sebagai Private Chat (individu)
      return false;
    }

    final conv = Conversation(
      id: getValue(['Id', 'id', 'RoomId', 'room_id'])?.toString() ?? '',
      contactId: getValue(['CtId', 'IdLink', 'LinkId', 'IdContact', 'ContactId', 'CtIdExt', 'ExtId', 'IdAlias'])?.toString() ?? '',
      participantEmail: getValue(['CtRealNm', 'CtNm', 'Nm', 'nm', 'Ct', 'Name', 'pushName', 'Title', 'participant_email', 'GroupNm', 'GroupName', 'group_name', 'Grp'])?.toString() ?? 'Unknown',
      lastMessage: finalLastMessage,
      lastMessageTime: getValue(['TimeMsg', 'In', 'last_message_time']) ?? '',
      unreadCount: int.tryParse(getValue(['Uc', 'uc', 'UC', 'unread_count', 'UnreadCount', 'Unread', 'unread', 'UnreadMsg', 'UnreadMsgs'])?.toString() ?? '') ?? 0,
      status: json['St'] != null
          ? resolveStatus(json['St'])
          : (getValue(['Status', 'status']) ?? 'Unassigned'),
      agentName: getValue(['AssignedAgentName', 'AgentName', 'agent_name']) ?? '',
      tags: parsedTags,
      avatarUrl: _resolveAvatarUrl(json),
      lastMessageType: rawLastMessageType,
      channelName: _resolveChannelName(json),
      channelType: getValue(['ChNm', 'ChannelName', 'chnm'])?.toString() ?? '',
      isPinned: json['IsPin'] == 2 || json['is_pinned'] == true,
      chId: getValue(['ChId', 'ch_id'])?.toString() ?? '',
      accountId: getValue(['IdAccount', 'idAccount', 'AccId', 'acc_id', 'AccountId', 'accountId', 'ChAccId', 'ch_acc_id', 'To', 'to'])?.toString() ?? '',
      funnel: rawFnName,
      tagsIds: rawTagsIds,
      funnelId: rawFnId,
      isGroup: resolveIsGroup(),
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
      link: getValue(['IdLink', 'LinkId', 'CtId', 'IdContact', 'CtIdExt', 'ExtId', 'IdAlias', 'LinkTmp', 'LinkNm', 'LinkName', 'link_name', 'Link'])?.toString() ?? '',
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
      isArchived: status.toLowerCase() == 'archived' || status == '4',
    );
  }
}
