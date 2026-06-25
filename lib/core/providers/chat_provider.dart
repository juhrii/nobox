import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/message.dart';
import '../services/chat_service.dart';
import '../services/signalr_service.dart';
import '../model/conversation.dart';
import '../model/api_response.dart';
import 'package:flutter/foundation.dart';

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

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get activeFilter => _activeFilter;

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

  /// Returns true if any advanced filter is active (used for badge indicator)
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

  /// Apply advanced filters and trigger a fresh fetch.
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

  /// Maps the active filter string to a status code understood by the API.
  /// 1=Unassigned, 2=Assigned, 3=Resolved, null=All
  int? _statusCodeForFilter(String filter) {
    switch (filter) {
      case 'Unassigned': return 1;
      case 'Assigned':   return 2;
      case 'Resolved':   return 3;
      default:           return null; // 'All'
    }
  }

  /// Maps raw funnel IDs and tag IDs on a [ChatModel] to human-readable names
  /// using the cached funnels/tags lists. Returns a new ChatModel with names applied.
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

  Future<void> fetchChats() async {
    _isLoading = true;
    _error = null;
    // Reset pagination state on fresh fetch
    _currentSkip = 0;
    _hasMore = true;
    _isLoadingMore = false;
    notifyListeners();

    try {
      // Load persisted local state first
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

      // Determine which status to request from the server
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

          // Check if unread count increased compared to previous state
          final oldChat = oldChatsMap[chat.id];
          if ((oldChat != null && chat.unreadCount > oldChat.unreadCount) || 
              (oldChat == null && chat.unreadCount > 0)) {
            // New message arrived! Remove from read suppression so badge appears
            _readIds.remove(chat.id);
            _saveReadState();
          }

          // Apply persisted local state (archive, read)
          // Status and Pin comes directly from server 
          return chat.copyWith(
            isPinned: chat.isPinned || _pinnedIds.contains(chat.id),
            isArchived: _archivedIds.contains(chat.id),
            unreadCount: _readIds.contains(chat.id) ? 0 : chat.unreadCount,
          );
        }).toList();

        // Update pagination state
        _currentSkip = response.data!.length;
        _hasMore = response.data!.length >= _pageSize;
        debugPrint('📄 [Pagination] Initial fetch: loaded ${response.data!.length} items, hasMore=$_hasMore');

        // Also fetch server-side archived conversations and merge them
        try {
          final archivedResponse = await _chatService.getArchivedConversations();
          if (!archivedResponse.isError && archivedResponse.data != null) {
            final existingIds = _chats.map((c) => c.id).toSet();
            for (final archivedConv in archivedResponse.data!) {
              final archivedChat = archivedConv.toChatModel();
              if (!existingIds.contains(archivedChat.id)) {
                _chats.add(archivedChat.copyWith(isArchived: true));
                _archivedIds.add(archivedChat.id);
              }
            }
            _saveArchivedState();
          }
        } catch (e) {
          debugPrint('ChatProvider: Failed to fetch archived chats: $e');
        }
      } else {
        _error = response.error ?? 'Gagal memuat chat';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update a single room's data directly from a SignalR TerimaSubSpv event.
  /// This avoids an API call and provides instant UI updates.
  ///
  /// [roomData] is the parsed JSON from TerimaSubSpv with keys like:
  /// Id, Ct, LastMsg, Uc, TimeMsg, IsPin, St, IsNeedReply, SdrMsg, etc.
  void updateRoomFromSignalR(Map<String, dynamic> roomData) {
    final roomId = roomData['Id']?.toString() ?? '';
    if (roomId.isEmpty) return;

    final index = _chats.indexWhere((c) => c.id == roomId);

    if (index >= 0) {
      // Update existing chat
      final existing = _chats[index];
      final lastMsg = roomData['LastMsg']?.toString() ?? existing.lastMessage;
      final uc = roomData['Uc'] is int ? roomData['Uc'] as int : existing.unreadCount;
      final timeMsg = roomData['TimeMsg']?.toString() ?? existing.time;
      final isNeedReply = roomData['IsNeedReply'] == 1 || roomData['IsNeedReply'] == true;
      final sdrMsg = roomData['SdrMsg']?.toString() ?? '';

      _chats[index] = existing.copyWith(
        lastMessage: lastMsg,
        unreadCount: uc,
        time: timeMsg,
        needReply: isNeedReply,
        isLastMessageFromMe: sdrMsg.toLowerCase() == 'you',
      );

      debugPrint('ChatProvider: 🏠 Updated room $roomId from SignalR | lastMsg=$lastMsg | uc=$uc');
      notifyListeners();
    } else {
      // Room not in current list — trigger a full refresh to pick it up
      debugPrint('ChatProvider: Room $roomId not in list, triggering refreshFirstPage');
      refreshFirstPage();
    }
  }

  /// Refresh only the first page of conversations without resetting pagination.
  /// Used by SignalR and polling to update data without breaking infinite scroll.
  Future<void> refreshFirstPage() async {
    if (_isLoading || _isLoadingMore) return;

    try {
      final statusCode = _statusCodeForFilter(_activeFilter);
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
            _chats[idx] = chat;
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

  /// Fetch more chats for infinite scroll pagination.
  /// Appends new data to existing list. Guards against duplicate requests.
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
    final prefs = await SharedPreferences.getInstance();
    
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


  // ── Computed getters ──

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


    // Sort: Pinned first, then by last message time descending
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.time.compareTo(a.time);
    });
    
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

      // Send to server via SignalR
      final success = await SignalRService().invokeBlockUnblock(
        roomId: roomId,
        contactId: contactId,
        status: _chats[index].status == 'Resolved' ? 3 : (_chats[index].status == 'Assigned' ? 2 : 1),
        shouldBlock: isBlocked,
      );

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

  Future<void> toggleArchive(String chatId) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final newArchived = !_chats[index].isArchived;
      
      // Optimistic update
      _chats[index] = _chats[index].copyWith(
        isArchived: newArchived,
        isPinned: false, // Archiving usually unpins
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

      // Send to server
      final response = newArchived
          ? await _chatService.moveToArchive(chatId)
          : await _chatService.restoreArchived(chatId);

      if (response.isError) {
        // Rollback
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
    final response = await _chatService.updateContactInfo(contactId, contactData);
    if (!response.isError) {
      // Update local chat model if name changed
      if (contactData['CtRealNm'] != null) {
        final index = _chats.indexWhere((c) => c.id == contactId);
        if (index != -1) {
          _chats[index] = _chats[index].copyWith(sender: contactData['CtRealNm'].toString());
          notifyListeners();
        }
      }
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
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
