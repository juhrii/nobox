import 'package:flutter/foundation.dart';
import 'message.dart';

// =====================================================================
// FITUR: Model Percakapan (Conversation/Chatroom)
// FILE: lib/core/model/conversation.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class model untuk menampung data list chat/room di halaman utama chat
// =====================================================================
class Conversation {

  // DEBUG: Static log buffer for API analysis
  static final List<String> _debugApiLog = [];
  static void dumpDebugLog() {
    print(dumpDebugLogStr());
  }

  static String dumpDebugLogStr() {
    if (_debugApiLog.isEmpty) {
      return '=== API DEBUG LOG EMPTY ===';
    }
    final sb = StringBuffer();
    sb.writeln('=== API DEBUG LOG (${_debugApiLog.length} messages) ===');
    for (var log in _debugApiLog) {
      sb.writeln(log);
    }
    sb.writeln('===========================');
    return sb.toString();
  }

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
      if (stValue == null) return 'Unassigned';
      if (stValue is String) {
        final lower = stValue.toLowerCase();
        if (lower == 'unassigned') return 'Unassigned';
        if (lower == 'assigned') return 'Assigned';
        if (lower == 'resolved') return 'Resolved';
        if (lower == 'archived') return 'Archived';
      }
      final st = stValue is int ? stValue : int.tryParse(stValue.toString());
      switch (st) {
        case 1: return 'Unassigned';
        case 2: return 'Assigned';
        case 3: return 'Resolved';
        case 4: return 'Archived';
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

    String finalLastMessage = resolveLastMessage(
      getValue(['LastMsg', 'last_message']),
      getValue(['Category'])
    );

    if (finalLastMessage.contains('[-{=||=}-]')) {
      finalLastMessage = '📍 Location';
    }

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
      final chNm = (getValue(['ChNm', 'ChannelName', 'chnm', 'ChId', 'ch_id', 'Channel'])?.toString() ?? '').trim().toLowerCase();
      final idStr = (getValue(['Id', 'id', 'RoomId', 'room_id'])?.toString() ?? '').trim().toLowerCase();
      final contactStr = (getValue(['CtRealId', 'ct_real_id', 'CtId', 'ContactId', 'IdLink', 'LinkId', 'LinkTmp', 'Link'])?.toString() ?? '').trim().toLowerCase();
      final combined = '$idStr $contactStr';

      // 1. ATURAN MUTLAK GROUP WHATSAPP: Pada channel WhatsApp, Grup WA WAJIB berakhiran / mengandung '@g.us' atau '@group'.
      if (combined.contains('@g.us') || combined.contains('@group')) {
        return true;
      }

      // 2. ATURAN MUTLAK TELEGRAM: Di Telegram, Grup selalu ber-ID negatif (awalan tanda minus '-'), user private bernilai positif.
      if (chNm.contains('telegram') || chNm.contains('tg') || combined.contains('telegram')) {
        if (idStr.startsWith('-') || contactStr.startsWith('-')) return true;
        return false;
      }

      // 3. ATURAN MUTLAK PRIVATE CHAT: Jika ID / Kontak / Link mengandung '@s.whatsapp.net', '@c.us',
      // atau FULL NUMERIC (hanya angka positif murni, misal nomor HP 628xxx atau ID kontak NoBox contoh: 723418040483845),
      // maka DIJAMIN 100% PRIVATE CHAT (INDIVIDU), mengabaikan flag IsGrp dari server yang salah kaprah!
      if (combined.contains('@s.whatsapp.net') || combined.contains('@c.us')) {
        return false;
      }

      final cleanContact = contactStr.replaceAll(RegExp(r'\s+'), '');
      if (cleanContact.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(cleanContact)) {
        return false;
      }
      final cleanId = idStr.replaceAll(RegExp(r'\s+'), '');
      if (cleanId.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(cleanId)) {
        return false;
      }

      // 4. Untuk channel lain yang ID-nya bukan angka murni, cek flag eksplisit dari server
      final grpFlag = getValue(['IsGrp', 'IsGroup', 'is_group', 'isGroup']);
      if (grpFlag != null && grpFlag.toString().isNotEmpty && grpFlag.toString() != 'null') {
        final strFlag = grpFlag.toString().trim().toLowerCase();
        if (strFlag == '1' || strFlag == 'true') return true;
        if (strFlag == '0' || strFlag == 'false') return false;
      }

      final chatType = (getValue(['ChatType', 'chat_type', 'Type', 'type'])?.toString() ?? '').trim().toLowerCase();
      if (chatType == 'group' || chatType == 'grup' || chatType == 'groupchat') return true;
      if (chatType == 'private' || chatType == 'personal' || chatType == 'user' || chatType == 'contact' || chatType == 'direct') return false;

      return false;
    }

    final conv = Conversation(
      id: getValue(['Id', 'id', 'RoomId', 'room_id'])?.toString() ?? '',
      contactId: getValue(['CtId', 'IdLink', 'LinkId', 'IdContact', 'ContactId', 'CtIdExt', 'ExtId', 'IdAlias'])?.toString() ?? '',
      participantEmail: getValue(['CtRealNm', 'CtNm', 'Nm', 'nm', 'Ct', 'Name', 'pushName', 'Title', 'participant_email', 'GroupNm', 'GroupName', 'group_name', 'Grp'])?.toString() ?? 'Unknown',
      lastMessage: finalLastMessage,
      lastMessageTime: getValue(['TimeMsg', 'In', 'last_message_time']) ?? '',
      unreadCount: int.tryParse(getValue(['Uc', 'uc', 'UC', 'unread_count', 'UnreadCount', 'Unread', 'unread', 'UnreadMsg', 'UnreadMsgs'])?.toString() ?? '') ?? 0,
      status: resolveStatus(json['St'] ?? getValue(['Status', 'status'])),
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
          json['IsMe'] == 1 ||
          json['IsMe'] == '1' ||
          json['IsMe'] == 'true' ||
          json['LastIsMe'] == true ||
          json['LastIsMe'] == 1 ||
          json['LastIsMe'] == '1' ||
          json['LastIsMe'] == 'true' ||
          getValue(['is_last_message_from_me', 'IsMeLast']) == true ||
          getValue(['is_last_message_from_me', 'IsMeLast']) == 1 ||
          getValue(['SdrMsg', 'sdr_msg', 'Sdr'])?.toString().toLowerCase() == 'you' ||
          getValue(['SdrMsg', 'sdr_msg', 'Sdr'])?.toString().toLowerCase() == 'me',
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

    // DEBUG: Accumulate raw API values for analysis
    final _dbgName = getValue(['CtRealNm', 'CtNm', 'Nm', 'nm', 'Ct', 'Name'])?.toString() ?? '?';
    final _dbgIsMe = json['IsMe'];
    final _dbgLastIsMe = json['LastIsMe'];
    final _dbgSdrMsg = getValue(['SdrMsg', 'sdr_msg', 'Sdr']);
    final _dbgNeedReply = json['NeedReply'] ?? json['IsNeedReply'];
    final _dbgLastMsg = (conv.lastMessage.length > 20) ? conv.lastMessage.substring(0, 20) : conv.lastMessage;
    final line = 'CONV [$_dbgName] IsMe=$_dbgIsMe(${_dbgIsMe.runtimeType}) LastIsMe=$_dbgLastIsMe SdrMsg=$_dbgSdrMsg NeedReply=$_dbgNeedReply => fromMe=${conv.isLastMessageFromMe} | msg=$_dbgLastMsg';
    _debugApiLog.add(line);
    if (_debugApiLog.length > 200) _debugApiLog.removeAt(0); // Keep last 200

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
      json['Photo'],      // Field utama untuk avatar contact (dari DetailRoom/API)
      json['photo'],
      json['CtImg'],      // Prioritas 2: Info Contact yang diupdate
      json['LinkImg'],    // Prioritas 3: Link Image bawaan channel (sering dipakai backend)
      json['Img'],
      json['AvatarUrl'],
      json['avatar_url'],
      json['ProfilePic'],
      json['profile_pic'],
      json['Picture'],
      json['picture'],
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

    // BINGO: C# Backend sering mereturn Windows path backslash (\) seperti "80404711\Contacts\xxx.jpg"
    // Ganti semua backslash menjadi forward slash agar URL valid
    raw = raw.replaceAll('\\', '/');

    // Jika sudah berupa URL penuh, gunakan apa adanya
    if (raw.startsWith('http')) return raw;
    
    // Bersihkan slash di depan jika ada
    if (raw.startsWith('/')) raw = raw.substring(1);
    
    // Jika string dari server sudah mengandung path upload, jangan ditambahkan lagi
    if (raw.toLowerCase().startsWith('upload/')) {
       return 'https://id.nobox.ai/$raw';
    }
    
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
