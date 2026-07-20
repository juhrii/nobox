import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/message.dart';
import '../services/chat_service.dart';
import '../services/signalr_service.dart';
import '../model/conversation.dart';
import '../model/api_response.dart';
import 'package:flutter/foundation.dart';

// =====================================================================
// FITUR: Provider Chat Utama
// FILE: lib/core/providers/chat_provider.dart
// BARIS AWAL: 13 (setelah komentar ini)
// FUNGSI: Mengelola state daftar chat utama, pagination, fitur pencarian, filter lanjutan, dan integrasi SignalR
// =====================================================================
class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  List<ChatModel> _chats = [];
  bool _isLoading = false;
  String? _error;

  // Pagination state
  static const int _pageSize = 20;
  int _currentSkip = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _searchQuery = '';
  String _activeFilter = 'All'; // All, Unassigned, Assigned, Resolved

  String? _filterMuteAi;
  String? _filterReadStatus;
  String? _filterChannel;
  String? _filterChatType;
  
  // New Advanced Filters
  List<String> _filterAccountIds = [];
  String? _filterContact;
  String? _filterLink;
  String? _filterGroup;
  String? _filterCampaign;
  String? _filterFunnel;
  String? _filterDeal;
  String? _filterTags;
  String? _filterHumanAgent;

  // Persisted local state
  Set<String> _pinnedIds = {};
  Set<String> _archivedIds = {};
  Set<String> _readIds = {};
  Set<String> _starredMessageIds = {};
  final List<Map<String, dynamic>> _starredMessages = [];

  static const String _pinnedKey = 'pinned_chats';
  static const String _archivedKey = 'archived_chats';
  static const String _readKey = 'read_chats';
  static const String _starredKey = 'starred_messages';
  static const String _starredDataKey = 'starred_messages_data';
  // Key untuk menyimpan nama kontak yang sudah di-save user secara lokal
  static const String _savedContactNamesKey = 'saved_contact_names';
  // Key untuk menyimpan data lokasi kontak secara lokal
  static const String _savedContactLocationsKey = 'saved_contact_locations';
  // Key untuk menyimpan override pesan lokal (supaya bertahan saat hot restart)
  static const String _localOverridesKey = 'local_overrides';

  // Map: roomId → nama kontak yang sudah disave (persisten melewati hot restart & refresh)
  Map<String, String> _savedContactNames = {};
  // Map: roomId → data lokasi kontak {Country, State, City, Address, Postal}
  Map<String, Map<String, String>> _savedContactLocations = {};
  
  // Map: roomId → list of ignored server times (used to ignore stale data after deleting a message)
  Map<String, List<String>> _ignoredServerTimes = {};

  void ignoreServerTime(String roomId, String time) {
    if (time.isEmpty) return;
    if (!_ignoredServerTimes.containsKey(roomId)) {
      _ignoredServerTimes[roomId] = [];
    }
    _ignoredServerTimes[roomId]!.add(time);
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get activeFilter => _activeFilter;
  List<Map<String, dynamic>>? get cachedAccounts => _cachedAccounts;

  String? get filterMuteAi => _filterMuteAi;
  String? get filterReadStatus => _filterReadStatus;
  String? get filterChannel => _filterChannel;
  String? get filterChatType => _filterChatType;
  
  List<String> get filterAccountIds => _filterAccountIds;
  String? get filterContact => _filterContact;
  String? get filterLink => _filterLink;
  String? get filterGroup => _filterGroup;
  String? get filterCampaign => _filterCampaign;
  String? get filterFunnel => _filterFunnel;
  String? get filterDeal => _filterDeal;
  String? get filterTags => _filterTags;
  String? get filterHumanAgent => _filterHumanAgent;

  /// Mengembalikan true jika ada filter lanjutan yang aktif (digunakan untuk indikator badge)
  bool get hasActiveAdvancedFilters =>
      _filterMuteAi != null ||
      _filterReadStatus != null ||
      _filterChannel != null ||
      _filterChatType != null ||
      _filterAccountIds.isNotEmpty ||
      _filterContact != null ||
      _filterLink != null ||
      _filterGroup != null ||
      _filterCampaign != null ||
      _filterFunnel != null ||
      _filterDeal != null ||
      _filterTags != null ||
      _filterHumanAgent != null;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setActiveFilter(String filter) {
    if (_activeFilter == filter) return; // skip jika sama
    _activeFilter = filter;
    // Reset pagination karena filter berubah
    _currentSkip = 0;
    _hasMore = true;
    _chats = [];
    notifyListeners();
    fetchChats();
  }

  // FITUR: Filter Lanjutan
  /// Terapkan filter lanjutan dan picu pengambilan data ulang (fresh fetch).
  ///
  /// Semua parameter ID harus berupa raw ID, bukan display name:
  /// - [contact]    → CtId (ID kontak)
  /// - [link]       → LinkTmp / ID link  (client-side filtered)
  /// - [group]      → Id group           (server-side filtered)
  /// - [campaign]   → Id campaign        (server-side filtered)
  /// - [funnel]     → Id funnel          (client-side filtered)
  /// - [deal]       → Id deal            (server-side filtered)
  /// - [tags]       → Id tag             (client-side filtered)
  /// - [humanAgent] → Id / UserId agent  (client-side filtered)
  ///
  /// **Jalur 1 – Server-Side** (dikirim via EqualityFilter ke backend):
  ///   Account, Contact, Group, Campaign, Deal
  ///
  /// **Jalur 2 – Client-Side** (di-remove dari payload, filter lokal .where()):
  ///   ChatType, ReadStatus, Link, Funnel, Tag, HumanAgent
  void applyAdvancedFilters({
    String? muteAi,
    String? readStatus,
    String? channel,
    String? chatType,
    List<String>? accountIds,
    String? contact,
    String? link,
    String? group,
    String? campaign,
    String? funnel,
    String? deal,
    String? tags,
    String? humanAgent,
  }) {
    _filterMuteAi = muteAi;
    _filterReadStatus = readStatus;
    _filterChannel = channel;
    _filterChatType = chatType;
    _filterAccountIds = accountIds ?? [];
    _filterContact = contact;
    _filterLink = link;
    _filterGroup = group;
    _filterCampaign = campaign;
    _filterFunnel = funnel;
    _filterDeal = deal;
    _filterTags = tags;
    _filterHumanAgent = humanAgent;
    // Reset pagination lalu trigger fresh fetch dengan filter baru
    _currentSkip = 0;
    _hasMore = true;
    _chats = [];
    notifyListeners();
    fetchChats();
  }

  void resetFilters() {
    _activeFilter = 'All';
    _filterMuteAi = null;
    _filterReadStatus = null;
    _filterChannel = null;
    _filterChatType = null;
    _filterAccountIds = [];
    _filterContact = null;
    _filterLink = null;
    _filterGroup = null;
    _filterCampaign = null;
    _filterFunnel = null;
    _filterDeal = null;
    _filterTags = null;
    _filterHumanAgent = null;
    notifyListeners();
    fetchChats();
  }

  void clearChatDataForAccountSwitch() {
    _chats.clear();
    _cachedFunnels = null;
    _cachedTags = null;
    _cachedAgents = null;
    _cachedLinks = null;
    _currentSkip = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }

  /// Memetakan string filter aktif ke kode status yang dipahami oleh API.
  /// 1=Unassigned, 2=Assigned, 3=Resolved, null=All
  int? _statusCodeForFilter(String filter) {
    switch (filter) {
      case 'Unassigned': return 1;
      case 'Assigned':   return 2;
      case 'Resolved':   return 3;
      default:           return null; // 'All'
    }
  }

  /// Memetakan ID funnel dan ID tag mentah pada [ChatModel] ke nama yang mudah dibaca manusia
  /// menggunakan daftar funnel/tag dari cache. Mengembalikan ChatModel baru dengan nama yang diterapkan.
  ChatModel _applyTagAndFunnelMapping(ChatModel chat, Conversation conv) {
    // Funnel: resolve ID → name
    if ((chat.funnel.isEmpty || int.tryParse(chat.funnel) != null) && conv.funnelId.isNotEmpty) {
      if (_cachedFunnels != null) {
        final matched = _cachedFunnels!.firstWhere(
          (f) => f['Id']?.toString() == conv.funnelId,
          orElse: () => <String, dynamic>{},
        );
        final name = matched['Name']?.toString() ?? matched['Nm']?.toString() ?? '';
        if (name.isNotEmpty) chat = chat.copyWith(funnel: name);
      }
    }
    // Tags: resolve IDs → names
    if (chat.tags.isEmpty && conv.tagsIds.isNotEmpty && conv.tagsIds != "null") {
      if (_cachedTags != null) {
        final tagIdList = conv.tagsIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e != "null").toList();
        final matchedNames = _cachedTags!
            .where((t) => tagIdList.contains(t['Id']?.toString()))
            .map((t) => t['Name']?.toString() ?? t['Nm']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        if (matchedNames.isNotEmpty) {
          chat = chat.copyWith(tags: matchedNames);
        } else if (tagIdList.any((id) => int.tryParse(id) == null)) {
          // Fallback: values are already names, not numeric IDs
          chat = chat.copyWith(tags: tagIdList);
        }
      }
    }
    return chat;
  }

  // FITUR: Ambil Data Chat
  // FUNGSI: Mengambil daftar percakapan dari server dengan dukungan pagination dan filter
    // FITUR 2: Mengambil daftar obrolan utama (20 data pertama) dari server.
Future<void> fetchChats() async {
    _isLoading = true;
    _error = null;
    // Reset state pagination saat pengambilan data baru
    _currentSkip = 0;
    _hasMore = true;
    _isLoadingMore = false;
    notifyListeners();

    try {
      // Muat state lokal yang tersimpan terlebih dahulu
      await _loadPersistedState();

      // Fetch funnels and tags proactively in the background for mapping
      // We explicitly await them here to ensure they format correctly immediately
      // Pre-fetch semua reference data yang dibutuhkan untuk
      // client-side ID-to-name resolution (Jalur 2 filters)
      await Future.wait([
        getFunnels(),
        getTags(),
        getCachedAgents(),
        getCachedLinks(),
        getCachedAccounts(), // FIX: Fetch accounts untuk resolusi channel type (ChId → Code)
      ]);

      // Tentukan status mana yang akan diminta dari server
      final statusCode = _statusCodeForFilter(_activeFilter);
      // ── Jalur 1: Server-Side Filters (dikirim via EqualityFilter) ──────────
      // Account, Contact, Group, Campaign, Deal, HumanAgent → server-side aman
      // MuteAi, Channel, ChatType, ReadStatus, Link, Funnel, Tag → client-side (Jalur 2)
      // NOTE: LinkTmp sebagai EqualityFilter = HTTP 500 (tidak didukung server)
      final response = await _chatService.getConversations(
        statusCode: statusCode,
        skip: 0,
        take: _pageSize,
        accountIds: _filterAccountIds.isNotEmpty ? _filterAccountIds.join(',') : null,
        contactId: _filterContact,        // CtRealId → server-side
        groupId: _filterGroup,            // GrpId → server-side aman
        campaignId: _filterCampaign,      // CampaignId → server-side aman
        dealId: _filterDeal,              // DealId → server-side aman
        humanAgentId: _filterHumanAgent,
        // linkId → TIDAK bisa: EqualityFilter LinkTmp = HTTP 500
        // funnelId, tagsId → client-side
      );

      if (!response.isError && response.data != null) {
        final freshData = response.data!;
        
        // Buat map dari chat yang sudah ada untuk komparasi unreadCount
        final oldChatsMap = {for (var c in _chats) c.id: c};

        _chats = freshData.map((c) {
          var chat = c.toChatModel();

          // FIX: Resolve channelType dari ChId menggunakan account cache
          // Contoh: ChId='1' → 'WhatsApp', ChId='2' → 'Telegram'
          if (chat.channelType.isEmpty && chat.chId.isNotEmpty) {
            final resolvedCode = _resolveChannelCode(chat.chId);
            if (resolvedCode.isNotEmpty) {
              chat = chat.copyWith(channelType: resolvedCode);
            }
          }

          // Apply locally cached mapping for tags and funnel
          chat = _applyTagAndFunnelMapping(chat, c);

          // Cek apakah jumlah pesan belum dibaca meningkat dibanding state sebelumnya
          final oldChat = oldChatsMap[chat.id];
          if ((oldChat != null && chat.unreadCount > oldChat.unreadCount) || 
              (oldChat == null && chat.unreadCount > 0)) {
            // Pesan baru tiba! Hapus dari daftar terbaca agar badge muncul
            _readIds.remove(chat.id);
            _saveReadState();
          }

          if (oldChat != null) {
            // FIX: Pertahankan isBlocked untuk Guest/New Contact (tanpa CtRealId)
            if (chat.ctRealId.isEmpty || chat.ctRealId == 'null') {
              if (oldChat.isBlocked) {
                chat = chat.copyWith(isBlocked: true);
              }
            }
            // FIX UNIVERSAL: Pertahankan nama kontak yang sudah di-save untuk SEMUA kontak.
            if (oldChat.sender.isNotEmpty && oldChat.sender != chat.sender) {
              final isOldSenderANumber = RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(oldChat.sender);
              final isNewSenderANumber = RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(chat.sender);
              if (!isOldSenderANumber || isNewSenderANumber) {
                chat = chat.copyWith(sender: oldChat.sender);
              }
            }

            // FIX UNIVERSAL MEDIA PRESERVATION:
            // Jika memori lokal mencatat pesan terakhir adalah media (Foto/Video/Voice),
            // tetapi API REST membalas dengan pesan kosong/generik (misal: "document(Empty)"),
            // TOLAK update API tersebut dan pertahankan wujud media lokalnya!
            final oldLower = oldChat.lastMessage.trim().toLowerCase();
            final isOldMedia = oldChat.lastMessageType == '2' || oldChat.lastMessageType == '3' || 
                               oldChat.lastMessageType == '4' || oldChat.lastMessageType == '5' || oldChat.lastMessageType == '16' ||
                               oldLower.contains('voice') || oldLower.contains('pesan suara') || 
                               oldLower.contains('photo') || oldLower.contains('foto') || 
                               oldLower.contains('video') || oldLower.contains('audio');
                               
            final newLower = chat.lastMessage.trim().toLowerCase();
            final isNewGeneric = newLower.isEmpty || newLower == 'document(empty)' || newLower == 'voice(empty)' || newLower == 'file' || newLower == 'null';
            
            if (isOldMedia && isNewGeneric) {
               chat = chat.copyWith(
                 lastMessageType: oldChat.lastMessageType,
                 lastMessage: oldChat.lastMessage, 
               );
            }
          }

          // Cek apakah ada override lokal (pesan dihapus/kirim pesan yang belum tersinkron di LastMessage server)
          final override = _localOverrides[chat.id];
          if (override != null) {
            final serverTime = DateTime.tryParse(chat.time) ?? DateTime.fromMillisecondsSinceEpoch(0);
            
            // Gunakan waktu PEMBUATAN override untuk membandingkan dengan serverTime,
            // bukan waktu pesan itu sendiri. Ini krusial saat menghapus pesan (waktu pesan mundur).
            final overrideCreatedAtStr = _overrideTimestamps[chat.id];
            final overrideCreatedAt = overrideCreatedAtStr != null ? DateTime.tryParse(overrideCreatedAtStr) ?? DateTime.now().toUtc() : (DateTime.tryParse(override.time) ?? DateTime.now().toUtc());
            
            final diff = overrideCreatedAt.difference(serverTime).inSeconds;
            
            // Beri toleransi waktu yang lebih besar (60 detik) untuk override media, 
            // karena upload ke server bisa lambat dan membuat serverTime lebih baru dari overrideCreatedAt.
            final isOverrideMedia = ['voice note', 'pesan suara', 'photo', 'foto', 'video', 'audio'].any((lbl) => override.lastMessage.toLowerCase().contains(lbl));
            final tolerance = isOverrideMedia ? -60 : -2;

            final isIgnored = _ignoredServerTimes[chat.id]?.contains(chat.time) ?? false;

            if (diff >= tolerance || isIgnored) {
               chat = chat.copyWith(
                 lastMessage: override.lastMessage,
                 time: override.time,
                 isLastMessageFromMe: override.isLastMessageFromMe,
               );
            } else {
               // Server sudah punya pesan yang lebih baru (melewati batas toleransi), hapus override
               _localOverrides.remove(chat.id);
               _overrideTimestamps.remove(chat.id);
            }
          }

          // Terapkan nama dari persistent storage (menang atas semua sumber lain)
          final persistedName = _savedContactNames[chat.id];
          if (persistedName != null && persistedName.isNotEmpty) {
            chat = chat.copyWith(sender: persistedName);
          }

          // FIX: Cegah string generik ("File", "Document") menimpa JSON array media yang sudah valid
          final shieldReference = oldChat ?? override;
          if (shieldReference != null) {
            final lowerNew = chat.lastMessage.toLowerCase().trim();
            final oldMsg = shieldReference.lastMessage.trim();
            
            final isGeneric = lowerNew.contains('file') || lowerNew.contains('document') || lowerNew.contains('voice note') || 
                              lowerNew.contains('photo') || lowerNew.contains('video') || lowerNew.contains('audio') || 
                              lowerNew.contains('image') || lowerNew.contains('attachment') || lowerNew.contains('pesan suara') ||
                              RegExp(r'^[\d\.:]+$').hasMatch(lowerNew);
            
            final oldIsLocalLabel = ['voice note', 'pesan suara', 'photo', 'foto', 'video', 'audio'].any((lbl) => oldMsg.toLowerCase().contains(lbl));

            if (isGeneric) {
              if (oldMsg.startsWith('{') || oldMsg.startsWith('[') || oldIsLocalLabel) {
                chat = chat.copyWith(
                  lastMessage: shieldReference.lastMessage,
                  lastMessageType: shieldReference.lastMessageType,
                );
              }
            } else if (lowerNew.startsWith('{') || lowerNew.startsWith('[')) {
              // Jika JSON baru datang, tapi tidak memiliki ciri-ciri audio yang jelas
              final newIsAudioJson = lowerNew.contains('"type":2') || lowerNew.contains('"type": 2') || lowerNew.contains('"ptt":true') || lowerNew.contains('"ptt": true') || lowerNew.contains('.ogg') || lowerNew.contains('.mp3') || lowerNew.contains('.opus');
              
              final oldIsAudioJson = oldMsg.toLowerCase().contains('"type":2') || oldMsg.toLowerCase().contains('"type": 2') || oldMsg.toLowerCase().contains('"ptt":true') || oldMsg.toLowerCase().contains('"ptt": true');
              final oldIsAudioLabel = oldMsg.toLowerCase().contains('voice note') || oldMsg.toLowerCase().contains('pesan suara');
              if ((oldIsAudioJson || oldIsAudioLabel) && !newIsAudioJson) {
                chat = chat.copyWith(
                  lastMessage: shieldReference.lastMessage,
                  lastMessageType: shieldReference.lastMessageType,
                );
              }
            } else if (oldIsLocalLabel || oldMsg.startsWith('{') || oldMsg.startsWith('[')) {
              if (lowerNew.isNotEmpty && oldMsg.toLowerCase().contains(lowerNew)) {
                chat = chat.copyWith(
                  lastMessage: shieldReference.lastMessage,
                  lastMessageType: shieldReference.lastMessageType,
                );
              }
            }
          }

          // Terapkan state lokal yang tersimpan (arsip, dibaca)
          // Status dan Pin berasal langsung dari server 
          return chat.copyWith(
            isPinned: chat.isPinned || _pinnedIds.contains(chat.id),
            isArchived: _archivedIds.contains(chat.id),
            unreadCount: _readIds.contains(chat.id) ? 0 : chat.unreadCount,
          );
        }).toList();

        // Perbarui state pagination
        _currentSkip = response.data!.length;
        _hasMore = response.data!.length >= _pageSize;
        debugPrint('📄 [Pagination] Initial fetch: loaded ${response.data!.length} items, hasMore=$_hasMore');

        // Segera perbarui UI agar pengguna tidak menunggu lama
        _isLoading = false;
        notifyListeners();

        // Ambil juga percakapan yang diarsipkan dari server dan gabungkan (di background)
        try {
          //getArchivedConversations() digunakan untuk memanggil API untuk menyelaraskan dengan databae sever
          final archivedResponse = await _chatService.getArchivedConversations();
          if (!archivedResponse.isError && archivedResponse.data != null) {
            final existingIds = _chats.map((c) => c.id).toSet();
            bool hasNewArchived = false;
            for (final archivedConv in archivedResponse.data!) {
              final archivedChat = archivedConv.toChatModel();
              if (!existingIds.contains(archivedChat.id)) {
                _chats.add(archivedChat.copyWith(isArchived: true));
                _archivedIds.add(archivedChat.id);
                hasNewArchived = true;
              }
            }
            if (hasNewArchived) {
              _saveArchivedState();
              notifyListeners();
            }
          }
        } catch (e) {
          debugPrint('ChatProvider: Failed to fetch archived chats: $e');
        }
      } else {
        _error = response.error ?? 'Gagal memuat chat';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memperbarui data satu ruang chat langsung dari event SignalR TerimaSubSpv.
  /// Ini menghindari pemanggilan API dan memberikan pembaruan UI instan.
  ///
  /// [roomData] is the parsed JSON from TerimaSubSpv with keys like:
  /// Id, Ct, LastMsg, Uc, TimeMsg, IsPin, St, IsNeedReply, SdrMsg, etc.
    // FITUR 3: Menyinkronkan status obrolan secara instan dari event SignalR.
  // [ACTION: UPDATE_ROOM_SIGNALR] - Memperbarui state chat saat ada pesan real-time masuk
  void updateRoomFromSignalR(Map<String, dynamic> roomData) {
    final roomId = roomData['Id']?.toString() ?? '';
    if (roomId.isEmpty) return;

    final index = _chats.indexWhere((c) => c.id == roomId);

    if (index >= 0) {
      // Update existing chat
      final existing = _chats[index];
      String lastMsg = roomData['LastMsg']?.toString() ?? existing.lastMessage;
      
      // FIX: Lindungi override lokal agar tidak tertimpa oleh data server yang USANG.
      // Override bertahan SELAMANYA sampai server mengirim pesan yang BENAR-BENAR lebih baru.
      if (_localOverrides.containsKey(roomId)) {
        final localChat = _localOverrides[roomId]!;
        final localTimeStr = localChat.time; // Waktu pesan lokal
        final localTime = DateTime.tryParse(localTimeStr.endsWith('Z') ? localTimeStr : '${localTimeStr}Z');
        final serverTimeStr = roomData['TimeMsg']?.toString() ?? '';
        final serverTime = DateTime.tryParse(serverTimeStr.endsWith('Z') ? serverTimeStr : '${serverTimeStr}Z');
        
        // Hanya terima data server jika waktu pesannya BENAR-BENAR lebih baru dari pesan lokal
        final isIgnored = _ignoredServerTimes[roomId]?.contains(serverTimeStr) ?? false;
        final serverIsNewer = (localTime != null && serverTime != null && serverTime.isAfter(localTime) && !isIgnored);
        
        if (serverIsNewer) {
          // Ada pesan baru yang sungguhan! Hapus override dan terima data server.
          _localOverrides.remove(roomId);
          _overrideTimestamps.remove(roomId);
          _saveLocalOverrides();
          debugPrint('ChatProvider: ✅ Override cleared for $roomId — server has newer message');
        } else {
          // Server masih mengembalikan data lama, PERTAHANKAN override lokal
          lastMsg = existing.lastMessage;
          roomData['LastMessageType'] = existing.lastMessageType;
          debugPrint('ChatProvider: 🛡️ Override protected for $roomId — server data is stale');
        }
      }

      // FIX: Cegah string generik ("File", "Document") menimpa JSON array media yang sudah valid
      final lowerNew = lastMsg.toLowerCase().trim();
      final oldMsg = existing.lastMessage.trim();
      
      final isGeneric = lowerNew.isEmpty || lowerNew == 'null' || lowerNew.contains('file') || lowerNew.contains('document') || lowerNew.contains('voice note') || 
                        lowerNew.contains('photo') || lowerNew.contains('video') || lowerNew.contains('audio') || 
                        lowerNew.contains('image') || lowerNew.contains('attachment') || lowerNew.contains('pesan suara') ||
                        RegExp(r'^[\d\.:]+$').hasMatch(lowerNew);
      
      final oldIsLocalLabel = ['voice note', 'pesan suara', 'photo', 'foto', 'video', 'audio'].any((lbl) => oldMsg.toLowerCase().contains(lbl));
      
      if (isGeneric) {
        if (oldMsg.startsWith('{') || oldMsg.startsWith('[') || oldIsLocalLabel) {
          lastMsg = existing.lastMessage;
        }
      } else if (lowerNew.startsWith('{') || lowerNew.startsWith('[')) {
        // Jika JSON baru datang, tapi tidak memiliki ciri-ciri audio yang jelas
        final newIsAudioJson = lowerNew.contains('"type":2') || lowerNew.contains('"type": 2') || lowerNew.contains('"ptt":true') || lowerNew.contains('"ptt": true') || lowerNew.contains('.ogg') || lowerNew.contains('.mp3') || lowerNew.contains('.opus');
        
        // Apakah pesan lama adalah audio? (JSON lengkap ATAU label manual)
        final oldIsAudioJson = oldMsg.toLowerCase().contains('"type":2') || oldMsg.toLowerCase().contains('"type": 2') || oldMsg.toLowerCase().contains('"ptt":true') || oldMsg.toLowerCase().contains('"ptt": true');
        final oldIsAudioLabel = oldMsg.toLowerCase().contains('voice note') || oldMsg.toLowerCase().contains('pesan suara');
        if ((oldIsAudioJson || oldIsAudioLabel) && !newIsAudioJson) {
          lastMsg = existing.lastMessage;
        }
      } else if (oldIsLocalLabel || oldMsg.startsWith('{') || oldMsg.startsWith('[')) {
        // Jika pesan baru bukan JSON dan bukan generic, MUNGKIN itu adalah caption yang di-strip oleh server.
        // Jika teks baru tersebut sudah ada di dalam pesan lama kita (misal: "📷 Photo Hello" mengandung "Hello"),
        // maka pertahankan pesan lama yang lebih kaya (punya icon/JSON).
        if (lowerNew.isNotEmpty && oldMsg.toLowerCase().contains(lowerNew)) {
          lastMsg = existing.lastMessage;
        }
      }

      final uc = roomData['Uc'] is int ? roomData['Uc'] as int : existing.unreadCount;
      final timeMsg = roomData['TimeMsg']?.toString() ?? existing.time;
      final isNeedReply = roomData['IsNeedReply'] == 1 || roomData['IsNeedReply'] == true;
      final sdrMsg = roomData['SdrMsg']?.toString() ?? '';

      // FIX Bug #3: Also update isBlocked from CtIsBlock if present
      final bool resolvedIsBlocked;
      if (roomData.containsKey('CtIsBlock')) {
        resolvedIsBlocked = roomData['CtIsBlock'] == 1 || roomData['CtIsBlock'] == true;
      } else {
        resolvedIsBlocked = existing.isBlocked;
      }

      // FIX Bug #4: Bersihkan LastMessageType yang usang jika pesan baru bukan JSON
      String? updatedType = roomData['LastMessageType']?.toString();
      if (!lastMsg.startsWith('{') && !lastMsg.startsWith('[')) {
        final lower = lastMsg.trim().toLowerCase();
        if (lower.isNotEmpty && lower != 'document(empty)' && lower != 'voice(empty)') {
          if (updatedType == '2' || updatedType == '3' || updatedType == '4' || updatedType == '5') {
            updatedType = '1';
          }
        }
      }
      if (updatedType == null) {
        final lower = lastMsg.trim().toLowerCase();
        if (lastMsg.startsWith('{') || lastMsg.startsWith('[') || lower.isEmpty || lower == 'null' || lower == 'document(empty)' || lower == 'voice(empty)') {
          updatedType = existing.lastMessageType;
        } else {
          updatedType = '1'; // Force Text
        }
      }

      _chats[index] = existing.copyWith(
        lastMessage: lastMsg,
        lastMessageType: updatedType,
        unreadCount: uc,
        time: timeMsg,
        needReply: isNeedReply,
        isLastMessageFromMe: sdrMsg.toLowerCase() == 'you',
        isBlocked: resolvedIsBlocked,
      );

      debugPrint('ChatProvider: 🏠 Updated room $roomId from SignalR | lastMsg=$lastMsg | uc=$uc');
      notifyListeners();
    } else {
      // Room not in current list — trigger a full refresh to pick it up
      debugPrint('ChatProvider: Room $roomId not in list, triggering refreshFirstPage');
      refreshFirstPage();
    }
  }

  // FIX: Backend kadang tidak mengirim TerimaSubSpv untuk Group Chat.
  // Jadi ketika TerimaPesan datang, kita periksa apakah room-nya ada. Jika tidak, paksa refresh!
  void handleTerimaPesanSync(String roomId) {
    if (roomId.isEmpty) return;
    final index = _chats.indexWhere((c) => c.id == roomId);
    if (index == -1) {
      debugPrint('ChatProvider: 🚨 Room $roomId missing on TerimaPesan! Triggering fallback refresh.');
      refreshFirstPage();
    }
  }

  /// Menyisipkan obrolan baru secara lokal ke urutan teratas tanpa harus menunggu server.
  /// Ini memperbaiki bug di mana obrolan baru menghilang atau melempar ke chat acak.
  void insertLocalChat(ChatModel chat) {
    // Hindari duplikasi
    final idx = _chats.indexWhere((c) => c.id == chat.id);
    if (idx != -1) {
      _chats[idx] = chat;
    } else {
      _chats.insert(0, chat);
    }
    notifyListeners();
  }

  void updateLocalLastMessage(String roomId, String lastMessage, {bool isFromMe = true, bool updateTimeAndPosition = true, String? overrideTime, String? lastMessageType}) {
    final index = _chats.indexWhere((c) => c.id == roomId);
    if (index >= 0) {
      final newTime = overrideTime ?? (updateTimeAndPosition ? DateTime.now().toUtc().toIso8601String() : _chats[index].time);
      final chat = _chats[index].copyWith(
        lastMessage: lastMessage,
        lastMessageType: lastMessageType ?? '1',
        isLastMessageFromMe: isFromMe,
        time: newTime,
      );
      
      // Simpan sebagai override agar tidak tertimpa Inbox/GetList yang usang
      _localOverrides[roomId] = chat;
      _overrideTimestamps[roomId] = DateTime.now().toUtc().toIso8601String(); // Catat KAPAN override ini dibuat
      
      
      if (updateTimeAndPosition) {
        // Pindahkan obrolan ke posisi paling atas
        _chats.removeAt(index);
        _chats.insert(0, chat);
      } else {
        // Hanya update di tempat, tapi waktu bisa mundur (misal saat hapus pesan)
        _chats[index] = chat;
        // Opsional: sort _chats jika ingin posisi langsung akurat saat pesan dihapus
        _chats.sort((a, b) => (b.time).compareTo(a.time));
      }
      
      _saveLocalOverrides();
      notifyListeners();
    }
  }

  /// Hanya merefresh halaman pertama percakapan tanpa mereset pagination.
  /// Digunakan oleh SignalR dan polling untuk memperbarui data tanpa merusak scroll tanpa batas.
  Future<void> refreshFirstPage({int? customStatusCode}) async {
    if (_isLoading || _isLoadingMore) return;

    try {
      final statusCode = customStatusCode ?? _statusCodeForFilter(_activeFilter);
      // ── Jalur 1: Server-Side Filters only ──────────────────────────────────
      final response = await _chatService.getConversations(
        statusCode: statusCode,
        skip: 0,
        take: _pageSize,
        accountIds: _filterAccountIds.isNotEmpty ? _filterAccountIds.join(',') : null,
        contactId: _filterContact,
        groupId: _filterGroup,
        campaignId: _filterCampaign,
        dealId: _filterDeal,
        humanAgentId: _filterHumanAgent,
        // linkId → HTTP 500, funnelId, tagsId → client-side
      );

      if (!response.isError && response.data != null) {
        final freshData = response.data!;
        final existingIds = _chats.map((c) => c.id).toSet();

        // Update existing chats yang datanya berubah
        for (final conv in freshData) {
          var chat = conv.toChatModel();

          // FIX: Resolve channelType dari ChId menggunakan account cache
          if (chat.channelType.isEmpty && chat.chId.isNotEmpty) {
            final resolvedCode = _resolveChannelCode(chat.chId);
            if (resolvedCode.isNotEmpty) {
              chat = chat.copyWith(channelType: resolvedCode);
            }
          }

          // Apply locally cached mapping for tags and funnel
          chat = _applyTagAndFunnelMapping(chat, conv);

          // Apply persisted local state
          chat = chat.copyWith(
            isPinned: chat.isPinned || _pinnedIds.contains(chat.id),
            isArchived: _archivedIds.contains(chat.id),
            unreadCount: _readIds.contains(chat.id) ? 0 : chat.unreadCount,
          );

          final idx = _chats.indexWhere((c) => c.id == chat.id);
          if (idx != -1) {
            final oldChat = _chats[idx];
            // FIX: Pertahankan nama kontak yang sudah di-save secara lokal.
            if (oldChat.sender.isNotEmpty && oldChat.sender != chat.sender) {
              final isOldSenderANumber = RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(oldChat.sender);
              final isNewSenderANumber = RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(chat.sender);
              if (!isOldSenderANumber || isNewSenderANumber) {
                chat = chat.copyWith(sender: oldChat.sender);
              }
            }
            // Terapkan nama dari persistent storage (prioritas tertinggi)
            final persistedName = _savedContactNames[chat.id];
            if (persistedName != null && persistedName.isNotEmpty) {
              chat = chat.copyWith(sender: persistedName);
            }

            // FIX: Lindungi override lokal agar tidak tertimpa oleh data server yang USANG.
            // Override bertahan SELAMANYA sampai server mengirim pesan yang BENAR-BENAR lebih baru.
            if (_localOverrides.containsKey(chat.id)) {
              final localChat = _localOverrides[chat.id]!;
              final localTimeStr = localChat.time;
              final localTime = DateTime.tryParse(localTimeStr.endsWith('Z') ? localTimeStr : '${localTimeStr}Z');
              final serverTimeStr = chat.time;
              final serverTime = DateTime.tryParse(serverTimeStr.endsWith('Z') ? serverTimeStr : '${serverTimeStr}Z');
              
              final isIgnored = _ignoredServerTimes[chat.id]?.contains(serverTimeStr) ?? false;
              final serverIsNewer = (localTime != null && serverTime != null && serverTime.isAfter(localTime) && !isIgnored);
              
              if (serverIsNewer) {
                // Ada pesan baru sungguhan, hapus override dan terima data server
                _localOverrides.remove(chat.id);
                _overrideTimestamps.remove(chat.id);
                _saveLocalOverrides();
                // Jatuh ke logika generic/label di bawah
              } else {
                // Server masih mengembalikan data lama, PERTAHANKAN override lokal
                chat = chat.copyWith(
                  lastMessage: oldChat.lastMessage,
                  lastMessageType: oldChat.lastMessageType,
                  time: oldChat.time,
                );
                _chats[idx] = chat;
                continue;
              }
            }
            
            // FIX: Cegah string generik ("File", "Document") menimpa JSON array media yang sudah valid
            final lowerNew = chat.lastMessage.toLowerCase().trim();
            final oldMsg = oldChat.lastMessage.trim();
            
            final isGeneric = lowerNew.contains('file') || lowerNew.contains('document') || lowerNew.contains('voice note') || 
                              lowerNew.contains('photo') || lowerNew.contains('video') || lowerNew.contains('audio') || 
                              lowerNew.contains('image') || lowerNew.contains('attachment') || lowerNew.contains('pesan suara');
            
            final oldIsLocalLabel = ['voice note', 'pesan suara', 'photo', 'foto', 'video', 'audio'].any((lbl) => oldMsg.toLowerCase().contains(lbl));

            if (isGeneric) {
              if (oldMsg.startsWith('{') || oldMsg.startsWith('[') || oldIsLocalLabel) {
                chat = chat.copyWith(
                  lastMessage: oldChat.lastMessage,
                  lastMessageType: oldChat.lastMessageType,
                );
              }
            } else if (lowerNew.startsWith('{') || lowerNew.startsWith('[')) {
              // Jika JSON baru datang, tapi tidak memiliki ciri-ciri audio yang jelas
              final newIsAudioJson = lowerNew.contains('"type":2') || lowerNew.contains('"type": 2') || lowerNew.contains('"ptt":true') || lowerNew.contains('"ptt": true') || lowerNew.contains('.ogg') || lowerNew.contains('.mp3') || lowerNew.contains('.opus');
              
              // Apakah pesan lama adalah audio? (JSON lengkap ATAU label manual)
              final oldIsAudioJson = oldMsg.toLowerCase().contains('"type":2') || oldMsg.toLowerCase().contains('"type": 2') || oldMsg.toLowerCase().contains('"ptt":true') || oldMsg.toLowerCase().contains('"ptt": true');
              final oldIsAudioLabel = oldMsg.toLowerCase().contains('voice note') || oldMsg.toLowerCase().contains('pesan suara');
              if ((oldIsAudioJson || oldIsAudioLabel) && !newIsAudioJson) {
                chat = chat.copyWith(
                  lastMessage: oldChat.lastMessage,
                  lastMessageType: oldChat.lastMessageType,
                );
              }
            } else if (oldIsLocalLabel || oldMsg.startsWith('{') || oldMsg.startsWith('[')) {
              // Jika pesan baru bukan JSON dan bukan generic, MUNGKIN itu adalah caption yang di-strip oleh server.
              // Jika teks baru tersebut sudah ada di dalam pesan lama kita (misal: "📷 Photo Hello" mengandung "Hello"),
              // maka pertahankan pesan lama yang lebih kaya (punya icon/JSON).
              if (lowerNew.isNotEmpty && oldMsg.toLowerCase().contains(lowerNew)) {
                chat = chat.copyWith(
                  lastMessage: oldChat.lastMessage,
                  lastMessageType: oldChat.lastMessageType,
                );
              }
            }

            _chats[idx] = chat;
          } else {
            // FIX: Bersihkan/Timpa dummy chat (yang dibuat lokal) jika contactId cocok
            // Ini mencegah duplikasi chat room (satu asli, satu dummy)
            final dummyIdx = _chats.indexWhere((c) => (c.id.isEmpty || c.id == '0') && c.contactId == chat.contactId);
            if (dummyIdx != -1) {
              _chats[dummyIdx] = chat;
              existingIds.add(chat.id); // Cegah agar tidak ditambah ganda di step newChats
            }
          }
        }

        // Tambahkan kontak baru yang belum ada
        final newChats = freshData
            .where((c) => !existingIds.contains(c.toChatModel().id))
            .map((c) {
              var chat = c.toChatModel();

              // FIX: Resolve channelType dari ChId menggunakan account cache
              if (chat.channelType.isEmpty && chat.chId.isNotEmpty) {
                final resolvedCode = _resolveChannelCode(chat.chId);
                if (resolvedCode.isNotEmpty) {
                  chat = chat.copyWith(channelType: resolvedCode);
                }
              }

              // Apply locally cached mapping for tags and funnel
              chat = _applyTagAndFunnelMapping(chat, c);
              
              // Terapkan nama dari persistent storage (prioritas tertinggi)
              final persistedName = _savedContactNames[chat.id];
              if (persistedName != null && persistedName.isNotEmpty) {
                chat = chat.copyWith(sender: persistedName);
              }

              // FIX: Terapkan local overrides saat app baru load (Hot Restart)
              if (_localOverrides.containsKey(chat.id)) {
                final localChat = _localOverrides[chat.id]!;
                final localTimeStr = localChat.time;
                final localTime = DateTime.tryParse(localTimeStr.endsWith('Z') ? localTimeStr : '${localTimeStr}Z');
                final serverTimeStr = chat.time;
                final serverTime = DateTime.tryParse(serverTimeStr.endsWith('Z') ? serverTimeStr : '${serverTimeStr}Z');
                
                final isIgnored = _ignoredServerTimes[chat.id]?.contains(serverTimeStr) ?? false;
                final serverIsNewer = (localTime != null && serverTime != null && serverTime.isAfter(localTime) && !isIgnored);
                
                if (serverIsNewer) {
                  // Ada pesan baru sungguhan dari server
                  _localOverrides.remove(chat.id);
                  _overrideTimestamps.remove(chat.id);
                  _saveLocalOverrides();
                } else {
                  // Server masih mengembalikan data lama, PERTAHANKAN override lokal
                  chat = chat.copyWith(
                    lastMessage: localChat.lastMessage,
                    lastMessageType: localChat.lastMessageType ?? chat.lastMessageType,
                    time: localChat.time,
                    isLastMessageFromMe: localChat.isLastMessageFromMe,
                  );
                }
              }

              return chat.copyWith(
                isPinned: chat.isPinned || _pinnedIds.contains(chat.id),
                isArchived: _archivedIds.contains(chat.id),
                unreadCount: _readIds.contains(chat.id) ? 0 : chat.unreadCount,
              );
            }).toList();


        if (newChats.isNotEmpty) {
          _chats.insertAll(0, newChats);
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('ChatProvider: refreshFirstPage error: $e');
    }
  }

  /// Mengambil lebih banyak chat untuk pagination scroll tanpa batas.
  /// Menambahkan data baru ke daftar yang sudah ada. Menjaga dari request ganda.
    // FITUR 2: Paging untuk mengambil data chat berikutnya berdasarkan posisi scroll.
Future<void> fetchMoreChats() async {
    // Guard: prevent duplicate fetch
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final statusCode = _statusCodeForFilter(_activeFilter);
      // ── Jalur 1: Server-Side Filters only ──────────────────────────────────
      final response = await _chatService.getConversations(
        statusCode: statusCode,
        skip: _currentSkip,
        take: _pageSize,
        accountIds: _filterAccountIds.isNotEmpty ? _filterAccountIds.join(',') : null,
        contactId: _filterContact,
        groupId: _filterGroup,
        campaignId: _filterCampaign,
        dealId: _filterDeal,
        humanAgentId: _filterHumanAgent,
        // linkId → HTTP 500, funnelId, tagsId → client-side
      );

      if (!response.isError && response.data != null) {
        final newConversations = response.data!;
        debugPrint('📄 [Pagination] Loaded ${newConversations.length} more items (skip=$_currentSkip)');

        if (newConversations.isEmpty) {
          _hasMore = false;
        } else {
          final existingIds = _chats.map((c) => c.id).toSet();

          final newChats = newConversations.map((c) {
            var chat = c.toChatModel();

            // Apply locally cached mapping for tags and funnel
            chat = _applyTagAndFunnelMapping(chat, c);

            // Apply persisted local state
            return chat.copyWith(
              isPinned: chat.isPinned || _pinnedIds.contains(chat.id),
              isArchived: _archivedIds.contains(chat.id),
              unreadCount: _readIds.contains(chat.id) ? 0 : chat.unreadCount,
            );
          }).where((chat) => !existingIds.contains(chat.id)).toList();

          _chats.addAll(newChats);
          _currentSkip += newConversations.length;
          
          // Jika data < 20, matikan hasMore
          if (newConversations.length < _pageSize) {
            _hasMore = false;
          } else {
            _hasMore = true;
          }
          
          debugPrint('📄 [Pagination] Total chats now: ${_chats.length}, hasMore=$_hasMore');
        }
      } else {
        debugPrint('📄 [Pagination] Error loading more: ${response.error}');
        // Don't set _hasMore to false on error — allow retry
      }
    } catch (e) {
      debugPrint('📄 [Pagination] Exception loading more: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Persisted State Management ──

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Overrides
      await _loadLocalOverrides();

      final pinnedJson = prefs.getString(_pinnedKey);
      if (pinnedJson != null) {
        _pinnedIds = Set<String>.from(jsonDecode(pinnedJson));
      }

      final archivedJson = prefs.getString(_archivedKey);
      if (archivedJson != null) {
        _archivedIds = Set<String>.from(jsonDecode(archivedJson));
      }

      final readJson = prefs.getString(_readKey);
      if (readJson != null) {
        _readIds = Set<String>.from(jsonDecode(readJson));
      }

      final starredJson = prefs.getString(_starredKey);
      if (starredJson != null) {
        _starredMessageIds = Set<String>.from(jsonDecode(starredJson));
      }

      final starredDataJson = prefs.getString(_starredDataKey);
      if (starredDataJson != null) {
        _starredMessages.clear();
        final list = jsonDecode(starredDataJson) as List;
        _starredMessages.addAll(list.cast<Map<String, dynamic>>());
      }

      // Load nama kontak yang sudah disave
      final savedNamesJson = prefs.getString(_savedContactNamesKey);
      debugPrint('ChatProvider: 🔍 savedContactNames raw: $savedNamesJson');
      if (savedNamesJson != null) {
        try {
          final decoded = jsonDecode(savedNamesJson) as Map<String, dynamic>;
          _savedContactNames = decoded.map((k, v) => MapEntry(k, v.toString()));
          debugPrint('ChatProvider: ✅ Loaded ${_savedContactNames.length} saved names: $_savedContactNames');
        } catch (e) {
          debugPrint('ChatProvider: ❌ Error decoding saved contact names: $e');
        }
      } else {
        debugPrint('ChatProvider: ⚠️ No saved contact names in prefs (key=$_savedContactNamesKey)');
      }

      // Load data lokasi kontak yang sudah disave
      final savedLocationsJson = prefs.getString(_savedContactLocationsKey);
      if (savedLocationsJson != null) {
        try {
          final decoded = jsonDecode(savedLocationsJson) as Map<String, dynamic>;
          _savedContactLocations = decoded.map((k, v) {
            final locMap = (v as Map<String, dynamic>).map((lk, lv) => MapEntry(lk, lv.toString()));
            return MapEntry(k, locMap);
          });
          debugPrint('ChatProvider: ✅ Loaded ${_savedContactLocations.length} saved locations');
        } catch (e) {
          debugPrint('ChatProvider: ❌ Error decoding saved contact locations: $e');
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: ❌ Error loading persisted state: $e');
    }
    
    notifyListeners();
  }

  Future<void> _savePinnedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinnedKey, jsonEncode(_pinnedIds.toList()));
  }

  Future<void> _saveArchivedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_archivedKey, jsonEncode(_archivedIds.toList()));
  }

  Future<void> _saveReadState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readKey, jsonEncode(_readIds.toList()));
  }

  Future<void> _saveStarredState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_starredKey, jsonEncode(_starredMessageIds.toList()));
    await prefs.setString(_starredDataKey, jsonEncode(_starredMessages));
  }

  /// Simpan peta nama kontak ke SharedPreferences agar bertahan melewati restart.
  Future<void> _saveSavedContactNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedContactNamesKey, jsonEncode(_savedContactNames));
  }

  /// Simpan peta data lokasi kontak ke SharedPreferences.
  Future<void> _saveSavedContactLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedContactLocationsKey, jsonEncode(_savedContactLocations));
  }

  /// Ambil data lokasi kontak yang disimpan secara lokal.
  Map<String, String>? getSavedContactLocation(String roomId) {
    return _savedContactLocations[roomId];
  }




  // ── Getter Terkomputasi ──

  int get unassignedCount => _chats.where((c) => !c.isArchived && c.status == 'Unassigned').length;
  int get assignedCount => _chats.where((c) => !c.isArchived && c.status == 'Assigned').length;
  int get resolvedCount => _chats.where((c) => !c.isArchived && c.status == 'Resolved').length;
  int get totalUnreadCount => _chats.where((c) => !c.isArchived).fold(0, (sum, c) => sum + c.unreadCount);

  // Unread per tab
  int get unassignedUnread => _chats.where((c) => !c.isArchived && c.status == 'Unassigned').fold(0, (sum, c) => sum + c.unreadCount);
  int get assignedUnread => _chats.where((c) => !c.isArchived && c.status == 'Assigned').fold(0, (sum, c) => sum + c.unreadCount);
  int get resolvedUnread => _chats.where((c) => !c.isArchived && c.status == 'Resolved').fold(0, (sum, c) => sum + c.unreadCount);

  // ── Starred Messages ──

  List<Map<String, dynamic>> get starredMessages => List.unmodifiable(_starredMessages);
  bool isStarred(String messageId) => _starredMessageIds.contains(messageId);

    // FITUR 12: Menyimpan pesan-pesan tertentu yang dianggap penting oleh user.
  // [ACTION: STAR_MESSAGE_TOGGLE] - Menyimpan/hapus pesan penting ke SharedPreferences
  void toggleStar(String messageId, {String? content, String? sender, String? time}) {
    if (_starredMessageIds.contains(messageId)) {
      _starredMessageIds.remove(messageId);
      _starredMessages.removeWhere((m) => m['id'] == messageId);
    } else {
      _starredMessageIds.add(messageId);
      _starredMessages.add({
        'id': messageId,
        'content': content ?? '',
        'sender': sender ?? '',
        'time': time ?? '',
        'starredAt': DateTime.now().toIso8601String(),
      });
    }
    _saveStarredState();
    notifyListeners();
  }

  // Getter untuk semua chat tanpa filter (berguna untuk lookup langsung by ID)
  List<ChatModel> get allChats => _chats;

  // Local overrides untuk lastMessage agar tidak tertimpa data usang dari server
  Map<String, ChatModel> _localOverrides = {};
  Map<String, String> _overrideTimestamps = {}; // Waktu kapan override dibuat (UTC)

  Future<void> _loadLocalOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final overridesJson = prefs.getString(_localOverridesKey);
      if (overridesJson != null) {
        final decoded = jsonDecode(overridesJson) as Map<String, dynamic>;
        _localOverrides.clear();
        for (final entry in decoded.entries) {
          final val = entry.value as Map<String, dynamic>;
          _localOverrides[entry.key] = ChatModel(
            id: entry.key,
            sender: '',
            lastMessage: val['lastMessage']?.toString() ?? '',
            time: val['time']?.toString() ?? '',
            isLastMessageFromMe: val['isLastMessageFromMe'] == true,
          );
        }
      }
      
      final timestampsJson = prefs.getString('override_timestamps');
      if (timestampsJson != null) {
        final Map<String, dynamic> decodedTs = jsonDecode(timestampsJson);
        _overrideTimestamps = decodedTs.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint('ChatProvider: Error loading local overrides: $e');
    }
  }

  Future<void> _saveLocalOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = _localOverrides.map((k, v) => MapEntry(k, {
        'lastMessage': v.lastMessage,
        'isLastMessageFromMe': v.isLastMessageFromMe,
        'time': v.time,
      }));
      await prefs.setString(_localOverridesKey, jsonEncode(data));
      await prefs.setString('override_timestamps', jsonEncode(_overrideTimestamps));
    } catch (e) {
      debugPrint('ChatProvider: Failed to save local overrides: $e');
    }
  }

  // [ACTION: FILTER_APPLY] - Getter ini mengeksekusi filter (lokal) pada daftar chat
  List<ChatModel> get chats {
    var filtered = _chats.where((chat) => !chat.isArchived).toList();

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((chat) => 
        chat.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        chat.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply Filter by status
    switch (_activeFilter) {
      case 'Unassigned':
        filtered = filtered.where((chat) => chat.status == 'Unassigned').toList();
        break;
      case 'Assigned':
        filtered = filtered.where((chat) => chat.status == 'Assigned').toList();
        break;
      case 'Resolved':
        filtered = filtered.where((chat) => chat.status == 'Resolved').toList();
        break;
    }

    // ══════════════════════════════════════════════════════════════════════
    // Advanced Filters — Arsitektur Dua Jalur
    // ══════════════════════════════════════════════════════════════════════
    // Jalur 1 (Server-Side): Account, Contact, Group, Campaign, Deal
    //   → Sudah difilter API via EqualityFilter. Tidak perlu filter lokal lagi.
    //
    // Jalur 2 (Client-Side): MuteAi, Channel, ChatType, ReadStatus,
    //                         Link, Funnel, Tag, HumanAgent
    //   → Filter lokal di sini menggunakan .where() + ID-to-name resolution.
    // ══════════════════════════════════════════════════════════════════════

    // MuteAi — client-side
    if (_filterMuteAi != null && _filterMuteAi != '--select--') {
      final isMuted = _filterMuteAi == 'Yes';
      filtered = filtered.where((c) => c.muteAiAgent == isMuted).toList();
    }

    // ReadStatus — client-side only (backend tidak support filter ini)
    if (_filterReadStatus != null && _filterReadStatus != '--select--') {
      final isRead = _filterReadStatus == 'Is Read'; // FIX: String dari UI adalah 'Is Read', bukan 'Read'
      filtered = filtered.where((c) => isRead ? c.unreadCount == 0 : c.unreadCount > 0).toList();
    }

    // Channel — client-side (berdasarkan Code dari account list, misal: 'WhatsApp', 'Telegram')
    // _filterChannel berisi string seperti 'WhatsApp' yang dibandingkan dengan channelType
    // channelType sudah di-resolve dari ChId → Code di saat fetch data.
    if (_filterChannel != null && _filterChannel != '--select--') {
      filtered = filtered.where((c) {
        // Primary: bandingkan dengan channelType (sudah di-resolve dari account Code)
        if (c.channelType.isNotEmpty) {
          return c.channelType.toLowerCase().contains(_filterChannel!.toLowerCase());
        }
        // Fallback: bandingkan channelName (nama akun) jika channelType kosong
        return c.channelName.toLowerCase().contains(_filterChannel!.toLowerCase());
      }).toList();
    }

    // ChatType — client-side only (backend tidak support IsGrp filter via EqualityFilter)
    if (_filterChatType != null && _filterChatType != '--select--') {
      final isGroup = _filterChatType == 'Group';
      filtered = filtered.where((c) => c.isGroup == isGroup).toList();
    }

    // Contact — FIX: Jalur 1 server-side mengirim CtId ke EqualityFilter.
    // Namun ContactItem.id = Entity Id dari /Nobox/Contact/List yang sama dengan CtRealId chatroom.
    // Tambahkan client-side fallback: cocokkan c.ctRealId (Entity Id) dengan _filterContact.
    if (_filterContact != null && _filterContact!.isNotEmpty) {
      filtered = filtered.where((c) =>
        c.ctRealId == _filterContact ||
        c.contactId == _filterContact  // fallback jika server-side tidak filter sempurna
      ).toList();
    }

    // ── Jalur 2: Filters berikut di-remove dari payload API ─────────────────

    // Link — CLIENT-SIDE ONLY
    // KONFIRMASI LOG: Chatlinkcontacts.Id = Chatroom.CtId
    // Contoh: Chatlinkcontacts {Id:814657018602245, Name:"Senikersku"}
    //         Chatroom: {CtId:814657018602245, Ct:"Senikersku"}
    // → filter: chat.contactId == _filterLink (membandingkan CtId)
    // EqualityFilter LinkTmp = HTTP 500 (tidak didukung server)
    if (_filterLink != null && _filterLink != '--select--') {
      filtered = filtered.where((c) =>
        c.contactId == _filterLink!
      ).toList();
      debugPrint('[Link Filter] filterLink=$_filterLink, hasil=${filtered.length}');
    }

    // Funnel — client-side only (mengirim FunnelId ke backend menyebabkan Error 500)
    // _filterFunnel menyimpan ID funnel → resolve ke nama untuk dibandingkan dengan chat.funnel
    if (_filterFunnel != null && _filterFunnel != '--select--') {
      final resolvedFunnelName = _resolveFunnelName(_filterFunnel!);
      if (resolvedFunnelName != null && resolvedFunnelName.isNotEmpty) {
        filtered = filtered.where((c) => c.funnel.toLowerCase() == resolvedFunnelName.toLowerCase()).toList();
      } else {
        // Fallback: bandingkan ID langsung
        filtered = filtered.where((c) => c.funnel.toLowerCase().contains(_filterFunnel!.toLowerCase())).toList();
      }
    }

    // Tag — client-side only (mengirim TagsIds ke backend menyebabkan Error 500)
    // _filterTags menyimpan ID tag → resolve ke nama untuk dibandingkan dengan chat.tags
    if (_filterTags != null && _filterTags != '--select--') {
      final resolvedTagName = _resolveTagName(_filterTags!);
      if (resolvedTagName != null && resolvedTagName.isNotEmpty) {
        filtered = filtered.where((c) => c.tags.any((t) => t.toLowerCase() == resolvedTagName.toLowerCase())).toList();
      } else {
        // Fallback: bandingkan ID langsung
        filtered = filtered.where((c) => c.tags.any((t) => t.toLowerCase() == _filterTags!.toLowerCase())).toList();
      }
    }


    // PENTING: sesama pinned chat kini diurutkan berdasarkan riwayat pin (statis) 
    // agar tidak bergerak posisi ketika ada pesan baru masuk atau di-refresh.
    final pinnedList = _pinnedIds.toList();
    final pinnedInOrder = filtered.where((c) => c.isPinned).toList()
      ..sort((a, b) {
        final indexA = pinnedList.indexOf(a.id);
        final indexB = pinnedList.indexOf(b.id);
        if (indexA != -1 && indexB != -1) {
          return indexB.compareTo(indexA); // Pin terbaru berada di urutan paling atas
        } else if (indexA != -1) {
          return -1;
        } else if (indexB != -1) {
          return 1;
        } else {
          return b.time.compareTo(a.time); // Fallback jika disematkan langsung dari server
        }
      });
      
    final unpinned = filtered.where((c) => !c.isPinned).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
      
    filtered = [...pinnedInOrder, ...unpinned];
    
    return filtered;
  }

  List<ChatModel> get archivedChats {
    return _chats.where((chat) => chat.isArchived).toList();
  }

  void markAsRead(String chatId) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1 && _chats[index].unreadCount > 0) {
      _readIds.add(_chats[index].id);
      _chats[index] = _chats[index].copyWith(unreadCount: 0);
      _saveReadState();
      notifyListeners();
    }
  }

  Future<void> togglePin(String chatId) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final newPinned = !_chats[index].isPinned;
      
      // Optimistic visual update
      _chats[index] = _chats[index].copyWith(isPinned: newPinned);
      if (newPinned) {
        _pinnedIds.add(chatId);
      } else {
        _pinnedIds.remove(chatId);
      }
      _savePinnedState();
      notifyListeners();

      // Send to server
      final response = await _chatService.togglePinRoom(chatId, newPinned);
      
      if (response.isError) {
        // Revert on error
        _chats[index] = _chats[index].copyWith(isPinned: !newPinned);
        if (!newPinned) {
          _pinnedIds.add(chatId);
        } else {
          _pinnedIds.remove(chatId);
        }
        _savePinnedState();
        notifyListeners();
      }
    }
  }

  Future<bool> toggleBlockContact(String roomId, String contactId, bool isBlocked) async {
    final index = _chats.indexWhere((chat) => chat.id == roomId);
    if (index != -1) {
      // Optimistic update
      _chats[index] = _chats[index].copyWith(isBlocked: isBlocked);
      notifyListeners();

      // Send to server via REST API (updateContactInfo) instead of SignalR to prevent server crash
      final updateResponse = await _chatService.updateContactInfo(
        roomId,
        {
          'CtIsBlock': isBlocked ? 1 : 0, 
          'IsBlock': isBlocked ? 1 : 0,
        },
      );
      final success = !updateResponse.isError;

      if (!success) {
        // Revert on error
        _chats[index] = _chats[index].copyWith(isBlocked: !isBlocked);
        notifyListeners();
        return false;
      }
      return true;
    }
    return false;
  }

  /// Sends a message via SignalR 'KirimPesan' instead of the REST API.
  /// Used specifically for real-time channels like Telegram.
  Future<String?> sendMessageViaSignalR({
    required ChatModel chat,
    required String type, // "1" for text, "3" for media
    String? msg,
    String? fileJson,
    String? replyId,
  }) async {
    String resolvedAccountId = chat.accountId;

    // --- TELEGRAM SMART FALLBACK ---
    // Chatrooms/List API sering mengembalikan AccId yang sudah kedaluwarsa untuk Telegram.
    // Web Dashboard secara otomatis menggunakan bot Telegram yang aktif.
    // Oleh karena itu, kita harus menimpa (override) resolvedAccountId dengan bot Telegram aktif dari _cachedAccounts.
    if (chat.chId == '2' || chat.channelType.toLowerCase().contains('telegram') || chat.channelName.toLowerCase().contains('telegram')) {
      if (_cachedAccounts != null) {
        try {
          final activeTelegramAcc = _cachedAccounts!.firstWhere(
            (acc) => acc['Channel']?.toString() == '2' || (acc['Code']?.toString() ?? '').toLowerCase().contains('telegram')
          );
          if (activeTelegramAcc['Id'] != null) {
            resolvedAccountId = activeTelegramAcc['Id'].toString();
            debugPrint('Telegram Smart Fallback: Overriding AccId ${chat.accountId} -> $resolvedAccountId');
          }
        } catch (e) {
          debugPrint('Telegram Smart Fallback Failed: $e');
        }
      }
    }
    // --------------------------------

    final error = await SignalRService().invokeKirimPesan(
      idLink: chat.contactId, // Harus contactId (CtId) karena backend menuntut INTEGER!
      idAccount: resolvedAccountId,
      idRoom: chat.id,
      idGroup: chat.groupId, // Pass groupId if it is a group
      type: type,
      msg: msg,
      fileJson: fileJson,
      replyId: replyId,
    );
    return error;
  }


  /// Update block status from incoming SignalR TerimaBlockUnblock event.
  /// Called from main.dart when server broadcasts a block/unblock change
  /// (e.g. from web nobox.ai).
  void updateBlockStatusFromSignalR(String roomId, bool isBlocked) {
    final index = _chats.indexWhere((c) => c.id == roomId);
    if (index >= 0) {
      _chats[index] = _chats[index].copyWith(isBlocked: isBlocked);
      debugPrint('ChatProvider: 🚫 Updated block status for room $roomId → isBlocked=$isBlocked');
      notifyListeners();
    } else {
      debugPrint('ChatProvider: 🚫 Room $roomId not found for block update, triggering refresh');
      refreshFirstPage();
    }
  }

    // FITUR 11: Menyembunyikan chat aktif ke ruang arsip dan mengembalikannya.
    // [ACTION: ARCHIVE_TOGGLE] - Otak pemrosesan saat arsip diubah dari UI
Future<void> toggleArchive(String chatId) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final newArchived = !_chats[index].isArchived;
      
      // Pembaruan UI seketika (Optimistic Update) agar aplikasi terasa cepat
      _chats[index] = _chats[index].copyWith(
        isArchived: newArchived,
        isPinned: false, // Biasanya jika diarsipkan, pin akan dilepas
      );
      
      if (newArchived) {
        _archivedIds.add(chatId);
        _pinnedIds.remove(chatId);
        _savePinnedState();
      } else {
        _archivedIds.remove(chatId);
      }
      _saveArchivedState();
      notifyListeners();

      // Kirim perintah arsip ke server
      final response = newArchived
          ? await _chatService.moveToArchive(chatId)
          : await _chatService.restoreArchived(chatId);

      if (response.isError) {
        // Kembalikan ke kondisi semula (Rollback) jika server gagal memproses
        _chats[index] = _chats[index].copyWith(isArchived: !newArchived);
        if (!newArchived) {
          _archivedIds.add(chatId);
        } else {
          _archivedIds.remove(chatId);
        }
        _saveArchivedState();
        _error = response.error;
        notifyListeners();
      }
    }
  }

  // ===========================================================================
  // CONTACT INFO UPDATES (Proxy to Service)
  // ===========================================================================

  Future<bool> updateContactTags(String contactId, List<String> tagIds, {List<String>? tagNames}) async {
    final response = await _chatService.updateContactTags(contactId, tagIds);
    if (!response.isError) {
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(tags: tagNames ?? tagIds);
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  void updateLocalContactTags(String contactId, List<String> tagIds, List<String> tagNames) {
    final index = _chats.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(tags: tagNames);
      notifyListeners();
    }
  }


  Future<bool> updateContactFunnel(String contactId, String funnelId, {String? funnelName}) async {
    final response = await _chatService.updateContactFunnel(contactId, funnelId);
    if (!response.isError) {
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        // Use the display name if provided, otherwise fallback to the ID string
        _chats[index] = _chats[index].copyWith(funnel: funnelName ?? funnelId);
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }
  
  Future<bool> updateContactNotes(String contactId, String notes) async {
    final response = await _chatService.updateContactNotes(contactId, notes);
    if (!response.isError) {
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(notes: notes);
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> updateContactDeal(String contactId, String pipeline, String stage, String deal) async {
    final response = await _chatService.updateContactDeal(contactId, pipeline, stage, deal);
    if (!response.isError) {
      // Just returning true. For a full implementation, you'd add pipeline/stage/deal to ChatModel
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<String?> uploadImage(File file) async {
    final response = await _chatService.uploadImage(file);
    if (!response.isError && response.data != null) {
      return response.data;
    }
    _error = response.error;
    notifyListeners();
    return null;
  }

  Future<bool> updateContactInfo(String contactId, Map<String, dynamic> contactData) async {
    debugPrint('ChatProvider: updateContactInfo called | roomId=$contactId | data=$contactData');

    // OPTIMISTIC SAVE: simpan nama ke memori dan disk SEBELUM memanggil API,
    // agar nama tetap tersimpan meski response API ambigu atau IsError=true.
    if (contactData['CtRealNm'] != null) {
      final newName = contactData['CtRealNm'].toString().trim();
      if (newName.isNotEmpty) {
        // 1. Update in-memory list
        final index = _chats.indexWhere((c) => c.id == contactId);
        if (index != -1) {
          _chats[index] = _chats[index].copyWith(sender: newName);
          notifyListeners();
        }
        // 2. Simpan ke persistent map
        _savedContactNames[contactId] = newName;
        // 3. Tulis ke disk segera (await agar pasti tersimpan sebelum hot restart)
        await _saveSavedContactNames();
        debugPrint('ChatProvider: 💾 Optimistically saved contact name "$newName" for room $contactId');
      }
    }

    // OPTIMISTIC SAVE: simpan data lokasi ke disk SEBELUM memanggil API,
    // agar lokasi tetap tersimpan meski API Contact/Update gagal.
    final locationFields = <String, String>{};
    for (final key in ['Country', 'State', 'City', 'Address', 'Postal']) {
      if (contactData[key] != null && contactData[key].toString().isNotEmpty) {
        locationFields[key] = contactData[key].toString();
      }
    }
    if (locationFields.isNotEmpty) {
      _savedContactLocations[contactId] = {
        ...(_savedContactLocations[contactId] ?? {}),
        ...locationFields,
      };
      await _saveSavedContactLocations();
      debugPrint('ChatProvider: 💾 Optimistically saved location for room $contactId: $locationFields');
    }

    final response = await _chatService.updateContactInfo(contactId, contactData);
    if (!response.isError) {
      return true;
    }
    // Meskipun API gagal, kita tetap return true jika data sudah di-persist lokal
    debugPrint('ChatProvider: ⚠️ updateContactInfo API returned error: ${response.error} — but local data is persisted');
    return true;
  }

  Future<bool> toggleAiAgent(String contactId, bool isMuted) async {
    final response = await _chatService.toggleAiAgent(contactId, isMuted);
    if (!response.isError) {
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(muteAiAgent: isMuted);
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> toggleNeedReply(String contactId, bool needReply) async {
    final response = await _chatService.toggleNeedReply(contactId, needReply);
    if (!response.isError) {
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(needReply: needReply);
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  // ===========================================================================
  // INBOX ACTIONS (Proxy to Service)
  // ===========================================================================

  Future<bool> assignChat(String contactId) async {
    final response = await _chatService.assignChat(contactId);
    if (!response.isError) {
      // Immediately update local UI for snappy feel
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(status: 'Assigned');
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> resolveChat(String contactId) async {
    final response = await _chatService.resolveChat(contactId);
    if (!response.isError) {
      // Immediately update local UI for snappy feel
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(status: 'Resolved');
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  // ===========================================================================
  // CONTACT INFO: CAMPAIGN, FORM TEMPLATE, DETAIL ROOM
  // ===========================================================================

  Future<bool> updateCampaign(String contactId, int? campaignId) async {
    final response = await _chatService.updateCampaign(contactId, campaignId);
    if (!response.isError) {
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> updateFormTemplate(String contactId, int? formTemplateId, {int? formResultId}) async {
    final response = await _chatService.updateFormTemplate(contactId, formTemplateId, formResultId: formResultId);
    if (!response.isError) {
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<List<Map<String, dynamic>>?> getFormTemplates() async {
    final response = await _chatService.getFormTemplates();
    if (!response.isError && response.data != null) {
      return response.data;
    }
    _error = response.error;
    return null;
  }

  Future<List<Map<String, dynamic>>?> getFormResults() async {
    final response = await _chatService.getFormResults();
    if (!response.isError && response.data != null) {
      return response.data;
    }
    _error = response.error;
    return null;
  }

  Future<Map<String, dynamic>?> getDetailRoom(String roomId) async {
    final response = await _chatService.getDetailRoom(roomId);
    if (!response.isError && response.data != null) {
      return response.data;
    }
    _error = response.error;
    return null;
  }

  // ===========================================================================
  // HUMAN AGENT METHODS
  // ===========================================================================

  Future<List<Map<String, dynamic>>?> getAgents() async {
    final response = await _chatService.getAgents();
    if (!response.isError && response.data != null) {
      return response.data;
    }
    _error = response.error;
    return null;
  }

  Future<bool> assignAgent(String contactId, String agentId, String agentName, {String chId = '', String ctId = ''}) async {
    final response = await _chatService.addAgentToConversation(contactId, agentId, agentName, chId: chId, ctId: ctId);
    if (!response.isError) {
      // Update local state immediately
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(agentName: agentName);
        notifyListeners();
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> removeAgent(String contactId) async {
    // Assuming passing empty id/name will unassign
    final response = await _chatService.addAgentToConversation(contactId, "", "");
    if (!response.isError) {
      final index = _chats.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(agentName: "");
        notifyListeners();
      }
      return true;
    }
    // If the API fails with empty string, we can fallback to simulating it on UI 
    // since the API behavior for unassigning isn't perfectly specified yet.
    debugPrint("Failed to remove agent via API, simulating success locally...");
    final index = _chats.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(agentName: "");
      notifyListeners();
    }
    return true;
  }

  // ===========================================================================
  // FUNNELS & TAGS LIST
  // ===========================================================================

  List<Map<String, dynamic>>? _cachedFunnels;
  List<Map<String, dynamic>>? _cachedTags;
  List<Map<String, dynamic>>? _cachedAgents; // untuk client-side HumanAgent filter
  List<Map<String, dynamic>>? _cachedLinks;  // untuk client-side Link filter
  List<Map<String, dynamic>>? _cachedAccounts; // untuk channel type resolution (ChId → Code)
  
  // Map dari ChId (string) ke Channel Code (misal: '1' → 'WhatsApp')
  // Dibangun dari _cachedAccounts saat accounts di-fetch
  Map<String, String> _chIdToChannelCode = {};

  // Cache untuk dialog filter agar tidak load berulang kali
  ApiResponse<List<Map<String, dynamic>>>? _cachedChannelsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedContactsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedGroupsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedCampaignsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedDealsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedAccountsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedLinksResponse;

  Future<ApiResponse<List<Map<String, dynamic>>>> getChannelsResponse() async {
    if (_cachedChannelsResponse != null) return _cachedChannelsResponse!;
    _cachedChannelsResponse = await _chatService.getChannels();
    return _cachedChannelsResponse!;
  }
  
  Future<ApiResponse<List<Map<String, dynamic>>>> getContactsResponse() async {
    if (_cachedContactsResponse != null) return _cachedContactsResponse!;
    _cachedContactsResponse = await _chatService.getContacts();
    return _cachedContactsResponse!;
  }
  
  Future<ApiResponse<List<Map<String, dynamic>>>> getGroupsResponse() async {
    if (_cachedGroupsResponse != null) return _cachedGroupsResponse!;
    _cachedGroupsResponse = await _chatService.getGroups();
    return _cachedGroupsResponse!;
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignsResponse() async {
    if (_cachedCampaignsResponse != null) return _cachedCampaignsResponse!;
    _cachedCampaignsResponse = await _chatService.getCampaigns();
    return _cachedCampaignsResponse!;
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getDealsResponse() async {
    if (_cachedDealsResponse != null) return _cachedDealsResponse!;
    _cachedDealsResponse = await _chatService.getDeals();
    return _cachedDealsResponse!;
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getAccountsResponse() async {
    if (_cachedAccountsResponse != null) return _cachedAccountsResponse!;
    _cachedAccountsResponse = await _chatService.getAccounts();
    
    // Build _chIdToChannelCode sekalian
    if (!_cachedAccountsResponse!.isError && _cachedAccountsResponse!.data != null) {
      _cachedAccounts = _cachedAccountsResponse!.data;
      _chIdToChannelCode = {};
      for (final account in _cachedAccounts!) {
        final channelNum = account['Channel']?.toString();
        final code = account['Code']?.toString();
        final accId = account['Id']?.toString();
        if (code != null && code.isNotEmpty) {
          if (channelNum != null && channelNum.isNotEmpty) _chIdToChannelCode[channelNum] = code;
          if (accId != null && accId.isNotEmpty) _chIdToChannelCode.putIfAbsent(accId, () => code);
        }
      }
    }
    
    return _cachedAccountsResponse!;
  }
  
  Future<ApiResponse<List<Map<String, dynamic>>>> getLinksResponse() async {
    if (_cachedLinksResponse != null) return _cachedLinksResponse!;
    _cachedLinksResponse = await _chatService.getLinks();
    
    // Build cache biasa juga
    if (!_cachedLinksResponse!.isError && _cachedLinksResponse!.data != null) {
      _cachedLinks = _cachedLinksResponse!.data;
    }
    
    return _cachedLinksResponse!;
  }

  Future<List<Map<String, dynamic>>?> getFunnels({bool forceRefresh = false}) async {
    if (_cachedFunnels != null && !forceRefresh) return _cachedFunnels;
    final response = await _chatService.getFunnels();
    if (!response.isError && response.data != null) {
      _cachedFunnels = response.data;
      return _cachedFunnels;
    }
    _error = response.error;
    return null;
  }

  Future<List<Map<String, dynamic>>?> getTags({bool forceRefresh = false}) async {
    if (_cachedTags != null && !forceRefresh) return _cachedTags;
    final response = await _chatService.getTags();
    if (!response.isError && response.data != null) {
      _cachedTags = response.data;
      return _cachedTags;
    }
    _error = response.error;
    return null;
  }

  /// Fetch dan cache list of Accounts.
  /// Membangun _chIdToChannelCode map untuk resolusi channel type.
  Future<List<Map<String, dynamic>>?> getCachedAccounts({bool forceRefresh = false}) async {
    if (_cachedAccounts != null && !forceRefresh) return _cachedAccounts;
    final response = await _chatService.getAccounts();
    if (!response.isError && response.data != null) {
      _cachedAccounts = response.data;
      // Build map: Channel (angka) → Code (nama platform)
      // Contoh: {"1": "WhatsApp", "2": "Telegram", "1505": "TokopediaCom"}
      _chIdToChannelCode = {};
      for (final account in _cachedAccounts!) {
        final channelNum = account['Channel']?.toString();
        final code = account['Code']?.toString();
        if (channelNum != null && channelNum.isNotEmpty && code != null && code.isNotEmpty) {
          _chIdToChannelCode[channelNum] = code;
        }
        // Juga map dari account Id ke code (untuk jaga-jaga jika ChId = AccId)
        final accId = account['Id']?.toString();
        if (accId != null && accId.isNotEmpty && code != null && code.isNotEmpty) {
          _chIdToChannelCode.putIfAbsent(accId, () => code);
        }
      }
      debugPrint('ChatProvider: _chIdToChannelCode = $_chIdToChannelCode');
      return _cachedAccounts;
    }
    debugPrint('ChatProvider: getCachedAccounts soft-fail: ${response.error}');
    return null;
  }

  /// Resolves ChId → Channel Code menggunakan [_chIdToChannelCode].
  /// Misal: '1' → 'WhatsApp', '2' → 'Telegram'
  String _resolveChannelCode(String chId) {
    return _chIdToChannelCode[chId] ?? '';
  }

  /// Fetch dan cache list of Agents.
  /// Digunakan untuk client-side HumanAgent filter (Jalur 2) — ID-to-name resolution.
  Future<List<Map<String, dynamic>>?> getCachedAgents({bool forceRefresh = false}) async {
    if (_cachedAgents != null && !forceRefresh) return _cachedAgents;
    final response = await _chatService.getAgents();
    if (!response.isError && response.data != null) {
      _cachedAgents = response.data;
      return _cachedAgents;
    }
    // Soft-fail: agents bersifat opsional untuk filtering, jangan propagate error
    debugPrint('ChatProvider: getCachedAgents soft-fail: ${response.error}');
    return null;
  }

  /// Fetch dan cache list of Links.
  /// Digunakan untuk client-side Link filter (Jalur 2) — ID-to-name resolution.
  Future<List<Map<String, dynamic>>?> getCachedLinks({bool forceRefresh = false}) async {
    if (_cachedLinks != null && !forceRefresh) return _cachedLinks;
    final response = await _chatService.getLinks();
    if (!response.isError && response.data != null) {
      _cachedLinks = response.data;
      return _cachedLinks;
    }
    // Soft-fail: links bersifat opsional untuk filtering, jangan propagate error
    debugPrint('ChatProvider: getCachedLinks soft-fail: ${response.error}');
    return null;
  }

  // ── ID-to-Name Resolvers (untuk Jalur 2 client-side filtering) ─────────────

  /// Resolves Funnel ID → display name menggunakan [_cachedFunnels].
  /// Returns null jika tidak ditemukan (caller harus fallback ke raw value).
  String? _resolveFunnelName(String id) {
    if (_cachedFunnels == null) return null;
    final matched = _cachedFunnels!.firstWhere(
      (f) => f['Id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return matched['Name']?.toString() ?? matched['Nm']?.toString();
  }

  /// Resolves Tag ID → display name menggunakan [_cachedTags].
  String? _resolveTagName(String id) {
    if (_cachedTags == null) return null;
    final matched = _cachedTags!.firstWhere(
      (t) => t['Id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return matched['Name']?.toString() ?? matched['Nm']?.toString();
  }

  /// Resolves HumanAgent ID → display name menggunakan [_cachedAgents].
  /// Cek field 'Id' dan 'UserId' untuk handle inkonsistensi backend.
  String? _resolveAgentName(String id) {
    if (_cachedAgents == null) return null;
    final matched = _cachedAgents!.firstWhere(
      (a) => a['Id']?.toString() == id || a['UserId']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return matched['DisplayName']?.toString() ??
           matched['Name']?.toString() ??
           matched['Nm']?.toString();
  }

  /// Resolves Link ID → template/display name menggunakan [_cachedLinks].
  String? _resolveLinkName(String id) {
    if (_cachedLinks == null) return null;
    final matched = _cachedLinks!.firstWhere(
      (l) => l['Id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return matched['Nm']?.toString() ??
           matched['Name']?.toString() ??
           matched['LinkTmp']?.toString();
  }
}
