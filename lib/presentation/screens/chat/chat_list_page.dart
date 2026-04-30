import 'package:flutter/material.dart';
import '../../widgets/searchable_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/model/message.dart';
import '../../../core/model/api_response.dart';
import '../../../core/model/conversation.dart';
import '../../../core/model/message_request.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/utils/app_routes.dart';
import 'chat_detail_page.dart';
import 'archive_list_page.dart';
import '../../widgets/chat_list_skeleton.dart';
import '../../widgets/connection_status_banner.dart';
import '../../../core/services/notification_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Unassigned', 'Assigned', 'Resolved'];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedChats = {};

  // Infinite scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchChats();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 200;
    
    final chatProvider = context.read<ChatProvider>();
    final isLoadingMore = chatProvider.isLoadingMore;
    final hasMore = chatProvider.hasMore;

    if (isNearBottom && !isLoadingMore && hasMore) {
      chatProvider.fetchMoreChats();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (!mounted) return;
    final newFilter = _tabs[_tabController.index];
    context.read<ChatProvider>().setActiveFilter(newFilter);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    return AppBar(
      backgroundColor: Colors.blue.shade600,
      elevation: 0,
      toolbarHeight: 64,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => setState(() => _selectedChats.clear()),
      ),
      title: Text(
        '${_selectedChats.length} selected',
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      actions: [

        IconButton(
          icon: const Icon(Icons.push_pin, color: Colors.white),
          onPressed: () async {
            for (var id in _selectedChats) {
              await chatProvider.togglePin(id);
            }
            setState(() => _selectedChats.clear());
          },
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text(
                  'Archive Conversation',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Are you sure you want to archive ${_selectedChats.length} conversation(s)?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      for (var id in _selectedChats) {
                        await chatProvider.toggleArchive(id);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${_selectedChats.length} chat(s) archived'),
                            backgroundColor: Colors.blue.shade700,
                          ),
                        );
                        setState(() => _selectedChats.clear());
                      }
                    },
                    child: const Text('Confirm', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: _selectedChats.isNotEmpty
          ? _buildSelectionAppBar(context)
          : AppBar(
        backgroundColor: Colors.blue,
        surfaceTintColor: Colors.blue,
        elevation: 0,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    context.read<ChatProvider>().setSearchQuery('');
                  });
                },
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/icons/nobox.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Cari chat...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            context.read<ChatProvider>().setSearchQuery('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  context.read<ChatProvider>().setSearchQuery(value);
                  setState(() {});
                },
              )
            : const Text(
                'NoBox Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 28),
                  onPressed: () {
                    setState(() { _isSearching = true; });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt, color: Colors.white, size: 28),
                  onPressed: () {
                    _showFilterDialog();
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                  onSelected: (value) {
                    if (value == 'archived') {
                      Navigator.pushNamed(context, AppRoutes.archivedChats);
                    } else if (value == 'dark_mode') {
                      themeProvider.toggleTheme(!isDark);
                    } else if (value == 'logout') {
                      _showLogoutDialog();
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: isDark ? const Color(0xFF2C3940) : Colors.white,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'dark_mode',
                      child: Row(
                        children: [
                          Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 16),
                          Text(isDark ? 'Light Mode' : 'Dark Mode', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archived',
                      child: Row(
                        children: [
                          Icon(Icons.archive, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 16),
                          const Text('Archived Conversation', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 24, color: Colors.red),
                          SizedBox(width: 16),
                          Text('Logout', style: TextStyle(color: Colors.red, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            padding: const EdgeInsets.only(bottom: 2.0),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Colors.blue, width: 3.0),
                insets: EdgeInsets.only(bottom: 2.0),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: _buildTabsWithBadges(context),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
            return const ChatListSkeleton();
          }

          final chats = chatProvider.chats;

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No chats found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  if (chatProvider.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      chatProvider.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => chatProvider.fetchChats(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.fetchChats(),
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              // +1 for the bottom indicator (loading skeleton or end-of-list)
              itemCount: chats.length + 1,
              itemBuilder: (context, index) {
                // Last item: show loading skeleton or end-of-list indicator
                if (index == chats.length) {
                  if (chatProvider.isLoadingMore) {
                    return _buildLoadingMoreSkeleton(isDark);
                  } else if (!chatProvider.hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Semua percakapan sudah ditampilkan',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }

                final chat = chats[index];
                return _buildChatTile(context, chat, chatProvider, isDark);
              },
            ),
          );
        },
      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewConversationDialog();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  List<Widget> _buildTabsWithBadges(BuildContext context) {
    return List.generate(_tabs.length, (i) {
      return Tab(
        text: _tabs[i],
      );
    });
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: context.read<ChatProvider>().searchQuery,
        );
        return AlertDialog(
          title: const Text('Search'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              context.read<ChatProvider>().setSearchQuery(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<ChatProvider>().setSearchQuery('');
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ── New Conversation Dialog ──
  void _showNewConversationDialog() {
    String selectedChat = 'Private';
    String? selectedChannel;
    String? selectedAccount;
    String selectedTo = 'Contact'; // Contact, Link, Manual
    String? selectedContact;
    String manualInput = '';
    String initialMessage = 'Hello';

    // API data
    List<Map<String, dynamic>> channels = [];
    List<Map<String, dynamic>> accounts = [];
    List<Map<String, dynamic>> contacts = [];
    bool isLoadingData = true;
    String? loadError;

    final chatService = ChatService();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Fetch data on first build
            if (isLoadingData && channels.isEmpty && loadError == null) {
              Future.microtask(() async {
                try {
                  final results = await Future.wait([
                    chatService.getChannels(),
                    chatService.getAccounts(),
                    chatService.getContacts(),
                  ]);

                  final channelResp = results[0] as ApiResponse<List<Map<String, dynamic>>>;
                  final accountResp = results[1] as ApiResponse<List<Map<String, dynamic>>>;
                  final contactResp = results[2] as ApiResponse<List<Map<String, dynamic>>>;

                  setDialogState(() {
                    isLoadingData = false;
                    if (!channelResp.isError && channelResp.data != null) {
                      channels = channelResp.data!;
                    }
                    if (!accountResp.isError && accountResp.data != null) {
                      accounts = accountResp.data!;
                    }
                    if (!contactResp.isError && contactResp.data != null) {
                      contacts = contactResp.data!;
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    isLoadingData = false;
                    loadError = e.toString();
                  });
                }
              });
            }

            // Helper to make list of unique display strings from API data
            List<String> toUniqueNames(List<Map<String, dynamic>> items, List<String> keys) {
              final names = <String>[];
              final seen = <String, int>{};
              for (final item in items) {
                String name = 'Unknown';
                for (final key in keys) {
                  final val = item[key]?.toString();
                  if (val != null && val.isNotEmpty) { name = val; break; }
                }
                // Deduplicate: append (2), (3), etc. for duplicates
                if (seen.containsKey(name)) {
                  seen[name] = seen[name]! + 1;
                  names.add('$name (${seen[name]})');
                } else {
                  seen[name] = 1;
                  names.add(name);
                }
              }
              return names;
            }

            Widget buildDropdownRow(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
              // Ensure value exists in options, otherwise reset to null
              final safeValue = (value != null && options.contains(value)) ? value : null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchableDropdown(
                        value: safeValue,
                        options: options,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Extract unique names from API data for dropdowns
            final channelNames = toUniqueNames(channels, ['Nm', 'Name', 'ChannelName']);
            final accountNames = toUniqueNames(accounts, ['Name', 'AccountName']);
            final contactNames = toUniqueNames(contacts, ['Name']);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New Conversation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isLoadingData)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading data...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    else if (loadError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text('Failed to load: $loadError', style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(onPressed: () {
                              setDialogState(() { isLoadingData = true; loadError = null; channels = []; });
                            }, child: const Text('Retry')),
                          ],
                        ),
                      )
                    else ...[
                      // Chat dropdown
                      buildDropdownRow('Chat', selectedChat, ['Private', 'Group'], (val) {
                        if (val != null) setDialogState(() => selectedChat = val);
                      }),

                      // Channel dropdown (from API)
                      buildDropdownRow('Channel', selectedChannel, channelNames, (val) {
                        setDialogState(() => selectedChannel = val);
                      }),

                      // Account dropdown (from API)
                      buildDropdownRow('Account', selectedAccount, accountNames, (val) {
                        setDialogState(() => selectedAccount = val);
                      }),

                      // To - Radio buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text(
                                  'To',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Wrap(
                                  spacing: 0,
                                  children: ['Contact', 'Link', 'Manual'].map((option) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: option,
                                          groupValue: selectedTo,
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => selectedTo = val);
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Text(option, style: const TextStyle(fontSize: 13)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Contact dropdown (from API) or Manual input
                      if (selectedTo == 'Contact')
                        buildDropdownRow('Contact', selectedContact, contactNames, (val) {
                          setDialogState(() => selectedContact = val);
                        })
                      else if (selectedTo == 'Manual')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 90,
                                child: Text('Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Enter phone number...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (val) => manualInput = val,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (selectedTo == 'Link')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 90,
                                child: Text('Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Paste link...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (val) => manualInput = val,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Initial Message field
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text('Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                maxLines: 3,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: 'Type an initial message...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (val) => initialMessage = val,
                                controller: TextEditingController(text: initialMessage),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Cancel & Create buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Find the receiver based on selection
                                String? receiver;
                                if (selectedTo == 'Contact' && selectedContact != null) {
                                  final contact = contacts.firstWhere(
                                    (c) => (c['Name']?.toString() ?? '') == selectedContact,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  // Use LeadLinks Id (the link between contact and channel)
                                  final leadLinks = contact['LeadLinks'];
                                  if (leadLinks is List && leadLinks.isNotEmpty) {
                                    // Use LeadLink Id as the receiver identifier
                                    receiver = leadLinks[0]['Id']?.toString();
                                  }
                                  // Fallback to contact Id
                                  receiver ??= contact['Id']?.toString();
                                } else if (selectedTo == 'Manual' || selectedTo == 'Link') {
                                  receiver = manualInput;
                                }

                                if (receiver == null || receiver.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Silakan pilih penerima')),
                                  );
                                  return;
                                }

                                if (initialMessage.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Pesan tidak boleh kosong')),
                                  );
                                  return;
                                }

                                // Get selected account Id
                                String? accountId;
                                if (selectedAccount != null) {
                                  final idx = accountNames.indexOf(selectedAccount!);
                                  if (idx >= 0 && idx < accounts.length) {
                                    accountId = accounts[idx]['Id']?.toString();
                                  }
                                }

                                Navigator.pop(dialogContext);

                                // Send initial message to create conversation
                                final response = await chatService.sendMessage(
                                  MessageRequest(
                                    receiver: receiver,
                                    content: initialMessage,
                                    accountId: accountId,
                                  ),
                                );

                                if (!response.isError) {
                                  // Refresh chat list and navigate
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pesan terkirim, obrolan sedang disiapkan...')),
                                    );
                                    
                                    if (mounted && _scrollController.hasClients) {
                                      _scrollController.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                    
                                    final chats = context.read<ChatProvider>().chats;
                                    if (chats.isNotEmpty) {
                                      // Cari chat yang sesuai dengan tujuan yang dipilih pengguna.
                                      // Jangan asal `chats.first` karena berpotensi race-condition jika server delay.
                                      final newChat = chats.firstWhere(
                                        (c) {
                                          if (receiver != null && c.contactId == receiver) return true;
                                          // sender is the contact name or phone number
                                          if (selectedContact != null && selectedContact!.isNotEmpty && c.sender.toLowerCase().contains(selectedContact!.toLowerCase())) return true;
                                          if (manualInput.isNotEmpty && c.sender.contains(manualInput)) return true;
                                          return false;
                                        },
                                        orElse: () => chats.first,
                                      );
                                      
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatDetailPage(chat: newChat),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal: ${response.error}')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Create'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArchivedTile(BuildContext context, int count) {
    return ListTile(
      leading: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.archive_outlined, color: Colors.blue),
      ),
      title: const Text(
        'Diarsipkan',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: Text(
        count.toString(),
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArchiveListPage()),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Shimmer skeleton loading indicator for infinite scroll (3 items)
  Widget _buildLoadingMoreSkeleton(bool isDark) {
    return _ShimmerLoadingWidget(isDark: isDark);
  }

  // ── Status badge helper ──
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Resolved':
        color = const Color(0xFF2E7D32); // Green
        break;
      case 'Assigned':
        color = const Color(0xFF1565C0); // Blue
        break;
      case 'Unassigned':
        color = const Color(0xFFE65100); // Orange
        break;
      default:
        color = Colors.grey.shade700;
    }

    // Ini untuk membuat label Status Tag khusus ('Assigned', 'Resolved', dll) di kanan bawah
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status == 'Assigned' ? Colors.blue.shade50 : Colors.white, // Background biru sangat muda
        border: Border.all(color: status == 'Assigned' ? Colors.blue.shade400 : color.withOpacity(0.5)), // Border warna biru
        borderRadius: BorderRadius.circular(15), // Corner bulat persis 15 sesuai instruksi
      ),
      child: Text(
        status,
        style: TextStyle(
          color: status == 'Assigned' ? Colors.blue.shade700 : color, // Teks biru kecil tapi jelas
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatModel chat, ChatProvider chatProvider, bool isDark) {
    final isSelected = _selectedChats.contains(chat.id);
    
    return _SwipeableChatTile(
      key: ValueKey('swipe_${chat.id}'),
      chat: chat,
      chatProvider: chatProvider,
      isDark: isDark,
      child: Container(
      color: isSelected ? (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50) : (isDark ? const Color(0xFF1F2C34) : Colors.white),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 0.5,
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
          ),
          InkWell(
            onTap: () {
              if (_selectedChats.isNotEmpty) {
                setState(() {
                  if (isSelected) _selectedChats.remove(chat.id);
                  else _selectedChats.add(chat.id);
                });
                return;
              }
              chatProvider.markAsRead(chat.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailPage(chat: chat),
                ),
              );
            },
            onLongPress: () {
              if (_selectedChats.isEmpty) {
                setState(() => _selectedChats.add(chat.id));
              } else {
                _showChatOptions(context, chat, chatProvider);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──
              if (_selectedChats.isNotEmpty)
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                    size: 28,
                  ),
                )
              else
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                      ? NetworkImage(chat.avatarUrl!)
                      : null,
                  child: chat.avatarUrl == null || chat.avatarUrl!.isEmpty
                      // Logika pengecekan: Jika chat adalah Group, gunakan ikon grup berombongan (Icons.group)
                      // Jika personal, gunakan ikon orang tunggal (Icons.person)
                      ? Icon(
                          chat.isGroup ? Icons.group : Icons.person,
                          color: Colors.grey.shade600,
                          size: 28,
                        )
                      : null,
                ),
              const SizedBox(width: 12),

              // ── Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Name
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.sender,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Row 2: Last message
                    _buildLastMessageRow(chat, isDark),

                    // Row 3: Tags & Funnel (inline)
                    if (chat.tags.isNotEmpty || chat.funnel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (chat.tags.isNotEmpty) ...[
                            Icon(Icons.local_offer, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                chat.tags.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                          if (chat.tags.isNotEmpty && chat.funnel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('|', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                            const SizedBox(width: 6),
                          ],
                          if (chat.funnel.isNotEmpty) ...[
                            Icon(Icons.filter_alt, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text(
                              chat.funnel,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Row 4: WhatsApp channel
                    if (chat.channelName.isNotEmpty && chat.channelName != 'Not Found') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          FaIcon(FontAwesomeIcons.whatsapp, size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              chat.channelName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // ── Trailing Content (Sisi Kanan) ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Jam & Pin (Row teratas sisi kanan)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(chat.time),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (chat.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin, size: 14, color: Colors.blue.shade400),
                      ],
                    ],
                  ),
                  
                  // Badge Unread
                  if (chat.unreadCount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  
                  // Status badge
                  const SizedBox(height: 6),
                  _buildStatusBadge(chat.status),
                ],
              ),
            ],
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 0.5,
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
      ),
    ],
  ),
),
    );
  }

  Widget _buildLastMessageRow(ChatModel chat, bool isDark) {
    // Logika warna berdasarkan pengirim (menggunakan properti needReply dari API):
    // Jika needReply = true -> Pesan butuh balasan (dari customer) -> Merah
    // Jika needReply = false -> Pesan tidak butuh balasan (dari agen) -> Hitam/Warna Tema
    final bool isFromCustomer = chat.needReply;
    
    // Jika dari customer = Merah. Jika dari agen = Hitam/Grey.
    final Color messageColor = isFromCustomer 
        ? Colors.red 
        : (isDark ? Colors.grey.shade400 : Colors.black87);
    
    // Check for special message types
    if (chat.lastMessageType != null && chat.lastMessageType!.isNotEmpty) {
      final isUnsupported = chat.lastMessageType!.toLowerCase().contains('unsupported');

      if (isUnsupported) {
        return Row(
          children: [
            Icon(Icons.block, size: 14, color: Colors.red.shade400),
            const SizedBox(width: 4),
            Text(
              chat.lastMessageType!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      }

      // Sticker or other special types
      return Row(
        children: [
          const Text('🌟 ', style: TextStyle(fontSize: 14)),
          Text(
            chat.lastMessageType!,
            style: TextStyle(
              fontSize: 13,
              color: messageColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Normal text message
    return Text(
      chat.lastMessage,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        color: messageColor,
      ),
    );
  }

  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawTime);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      // If not parseable, return as-is (legacy format)
      return rawTime;
    }
  }

  // ── Filter Conversation Dialog ──
  void _showFilterDialog() {
    final provider = context.read<ChatProvider>();
    final chatService = ChatService(); // Create locally for services not exposed through provider

    // Local state for dropdowns synchronized with provider
    String? selectedStatus = provider.activeFilter == 'All' ? null : provider.activeFilter;
    if (!['Assigned', 'Unassigned', 'Resolved'].contains(selectedStatus)) {
      selectedStatus = null;
    }
    String? selectedMuteAi = provider.filterMuteAi;
    String? selectedReadStatus = provider.filterReadStatus;
    String? selectedChannel = provider.filterChannel;
    String? selectedChat = provider.filterChatType;
    String? selectedAccount = provider.filterAccount;
    String? selectedContact = provider.filterContact;
    String? selectedLink = provider.filterLink;
    String? selectedGroup = provider.filterGroup;
    String? selectedCampaign = provider.filterCampaign;
    String? selectedFunnel = provider.filterFunnel;
    String? selectedDeal = provider.filterDeal;
    String? selectedTags = provider.filterTags;
    String? selectedHumanAgent = provider.filterHumanAgent;

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: Future.wait([
            chatService.getChannels(),
            chatService.getAccounts(),
            chatService.getContacts(),
            chatService.getGroups(),
            chatService.getCampaigns(),
            provider.getFunnels(),
            chatService.getDeals(),
            provider.getTags(),
            provider.getAgents(),
            chatService.getLinks(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Extract lists gracefully
            final channelsRaw = snapshot.data?[0] as ApiResponse<List<Map<String, dynamic>>>?;
            final channels = channelsRaw?.data?.map((e) => e['Nm']?.toString() ?? e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final accountsRaw = snapshot.data?[1] as ApiResponse<List<Map<String, dynamic>>>?;
            final accounts = accountsRaw?.data?.map((e) => e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final contactsRaw = snapshot.data?[2] as ApiResponse<List<Map<String, dynamic>>>?;
            final contacts = contactsRaw?.data?.map((e) => e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final groupsRaw = snapshot.data?[3] as ApiResponse<List<Map<String, dynamic>>>?;
            final groups = groupsRaw?.data?.map((e) => e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final campaignsRaw = snapshot.data?[4] as ApiResponse<List<Map<String, dynamic>>>?;
            final campaigns = campaignsRaw?.data?.map((e) => e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final funnelsRaw = snapshot.data?[5] as List<Map<String, dynamic>>?;
            final funnels = funnelsRaw?.map((e) => e['Name']?.toString() ?? e['Nm']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final dealsRaw = snapshot.data?[6] as ApiResponse<List<Map<String, dynamic>>>?;
            final deals = dealsRaw?.data?.map((e) => e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final tagsRaw = snapshot.data?[7] as List<Map<String, dynamic>>?;
            final tags = tagsRaw?.map((e) => e['Name']?.toString() ?? e['Nm']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final agentsRaw = snapshot.data?[8] as List<Map<String, dynamic>>?;
            final agents = agentsRaw?.map((e) => e['Name']?.toString() ?? e['Nm']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            final linksRaw = snapshot.data?[9] as ApiResponse<List<Map<String, dynamic>>>?;
            final links = linksRaw?.data?.map((e) => e['Name']?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];

            // Prevent dropdowns from crashing if the selected local value no longer exists in options list.
            if (selectedChannel != null && !channels.contains(selectedChannel) && selectedChannel != '--select--') channels.add(selectedChannel!);
            if (selectedAccount != null && !accounts.contains(selectedAccount) && selectedAccount != '--select--') accounts.add(selectedAccount!);
            if (selectedContact != null && !contacts.contains(selectedContact) && selectedContact != '--select--') contacts.add(selectedContact!);
            if (selectedGroup != null && !groups.contains(selectedGroup) && selectedGroup != '--select--') groups.add(selectedGroup!);
            if (selectedCampaign != null && !campaigns.contains(selectedCampaign) && selectedCampaign != '--select--') campaigns.add(selectedCampaign!);
            if (selectedFunnel != null && !funnels.contains(selectedFunnel) && selectedFunnel != '--select--') funnels.add(selectedFunnel!);
            if (selectedDeal != null && !deals.contains(selectedDeal) && selectedDeal != '--select--') deals.add(selectedDeal!);
            if (selectedTags != null && !tags.contains(selectedTags) && selectedTags != '--select--') tags.add(selectedTags!);
            if (selectedHumanAgent != null && !agents.contains(selectedHumanAgent) && selectedHumanAgent != '--select--') agents.add(selectedHumanAgent!);
            if (selectedLink != null && !links.contains(selectedLink) && selectedLink != '--select--') links.add(selectedLink!);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                Widget buildDropdownRow(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
                  final safeValue = (value == null || value == '--select--' || !options.contains(value)) ? null : value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SearchableDropdown(
                            value: safeValue,
                            options: options,
                            onChanged: onChanged,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Filter Conversation',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                        // Apply & Reset buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Apply filter
                                  provider.setActiveFilter(selectedStatus ?? 'All');
                                  provider.applyAdvancedFilters(
                                    muteAi: selectedMuteAi,
                                    readStatus: selectedReadStatus,
                                    channel: selectedChannel,
                                    chatType: selectedChat,
                                    account: selectedAccount,
                                    contact: selectedContact,
                                    link: selectedLink,
                                    group: selectedGroup,
                                    campaign: selectedCampaign,
                                    funnel: selectedFunnel,
                                    deal: selectedDeal,
                                    tags: selectedTags,
                                    humanAgent: selectedHumanAgent,
                                  );
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.filter_alt, size: 18),
                                label: const Text('Apply'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedStatus = null;
                                    selectedMuteAi = null;
                                    selectedReadStatus = null;
                                    selectedChannel = null;
                                    selectedChat = null;
                                    selectedAccount = null;
                                    selectedContact = null;
                                    selectedLink = null;
                                    selectedGroup = null;
                                    selectedCampaign = null;
                                    selectedFunnel = null;
                                    selectedDeal = null;
                                    selectedTags = null;
                                    selectedHumanAgent = null;
                                  });
                                  provider.resetFilters();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reset'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // Scrollable filter rows
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            child: Column(
                              children: [
                                buildDropdownRow('Status', selectedStatus, ['Assigned', 'Unassigned', 'Resolved'], (val) {
                                  setDialogState(() => selectedStatus = val);
                                }),
                                buildDropdownRow('Is Mute Ai Agent', selectedMuteAi, ['Yes', 'No'], (val) {
                                  setDialogState(() => selectedMuteAi = val);
                                }),
                                buildDropdownRow('Read Status', selectedReadStatus, ['Read', 'Unread'], (val) {
                                  setDialogState(() => selectedReadStatus = val);
                                }),
                                buildDropdownRow('Channel', selectedChannel, channels.isEmpty ? ['WhatsApp', 'Telegram', 'Email', 'Web'] : channels, (val) {
                                  setDialogState(() => selectedChannel = val);
                                }),
                                buildDropdownRow('Chat', selectedChat, ['Personal', 'Group'], (val) {
                                  setDialogState(() => selectedChat = val);
                                }),
                                buildDropdownRow('Account', selectedAccount, accounts.isEmpty ? ['All Accounts'] : accounts, (val) {
                                  setDialogState(() => selectedAccount = val);
                                }),
                                buildDropdownRow('Contact', selectedContact, contacts.isEmpty ? ['All Contacts'] : contacts, (val) {
                                  setDialogState(() => selectedContact = val);
                                }),
                                buildDropdownRow('Link', selectedLink, links.isEmpty ? ['Linked', 'Unlinked'] : links, (val) {
                                  setDialogState(() => selectedLink = val);
                                }),
                                buildDropdownRow('Group', selectedGroup, groups.isEmpty ? ['All Groups'] : groups, (val) {
                                  setDialogState(() => selectedGroup = val);
                                }),
                                buildDropdownRow('Campaign', selectedCampaign, campaigns.isEmpty ? ['All Campaigns'] : campaigns, (val) {
                                  setDialogState(() => selectedCampaign = val);
                                }),
                                buildDropdownRow('Funnel', selectedFunnel, funnels.isEmpty ? ['All Funnels'] : funnels, (val) {
                                  setDialogState(() => selectedFunnel = val);
                                }),
                                buildDropdownRow('Deal', selectedDeal, deals.isEmpty ? ['All Deals'] : deals, (val) {
                                  setDialogState(() => selectedDeal = val);
                                }),
                                buildDropdownRow('Tags', selectedTags, tags.isEmpty ? ['All Tags'] : tags, (val) {
                                  setDialogState(() => selectedTags = val);
                                }),
                                buildDropdownRow('Human Agents', selectedHumanAgent, agents.isEmpty ? ['All Agents'] : agents, (val) {
                                  setDialogState(() => selectedHumanAgent = val);
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showChatOptions(BuildContext context, ChatModel chat, ChatProvider chatProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(
              chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              color: Colors.blue,
            ),
            title: Text(chat.isPinned ? 'Lepas Pin Chat' : 'Sematkan Chat (Pin)'),
            onTap: () {
              chatProvider.togglePin(chat.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    chat.isPinned
                        ? 'Pin ${chat.sender} dilepas'
                        : '${chat.sender} disematkan di atas',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined, color: Colors.blue),
            title: const Text('Arsipkan Chat'),
            onTap: () {
              Navigator.pop(context); // close bottom sheet first
              showDialog(
                context: this.context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text(
                    'Archive Conversation',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  content: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      'Are you sure you want to archive this conversation?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await chatProvider.toggleArchive(chat.id);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('${chat.sender} archived successfully'),
                              backgroundColor: Colors.blue.shade700,
                            ),
                          );
                        }
                      },
                      child: const Text('Confirm', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              );
            },
          ),
          // ── Assign / Resolve Actions ──
          if (chat.status != 'Assigned')
            ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: Colors.orange),
              title: const Text('Assign ke Saya'),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Mengassign chat...')),
                );
                final success = await chatProvider.assignChat(chat.id);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? '${chat.sender} berhasil di-assign!'
                          : 'Gagal meng-assign chat'),
                    ),
                  );
                }
              },
            ),
          if (chat.status != 'Resolved')
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Selesaikan (Resolve)'),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Menyelesaikan chat...')),
                );
                final success = await chatProvider.resolveChat(chat.id);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? '${chat.sender} berhasil diselesaikan!'
                          : 'Gagal menyelesaikan chat'),
                    ),
                  );
                }
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Swipeable Chat Tile Widget ──
// Widget terpisah untuk membungkus setiap chat tile dengan aksi geser (swipe).
// Geser ke kanan = Pin/Unpin, Geser ke kiri = Arsip.
class _SwipeableChatTile extends StatefulWidget {
  final ChatModel chat;
  final ChatProvider chatProvider;
  final bool isDark;
  final Widget child;

  const _SwipeableChatTile({
    super.key,
    required this.chat,
    required this.chatProvider,
    required this.isDark,
    required this.child,
  });

  @override
  State<_SwipeableChatTile> createState() => _SwipeableChatTileState();
}

class _SwipeableChatTileState extends State<_SwipeableChatTile> {
  @override
  Widget build(BuildContext context) {
    // Swipe-to-action has been removed per request. Returning child directly.
    return widget.child;
  }
}

/// Shimmer loading widget for infinite scroll pagination.
/// Shows 3 skeleton items with animated shimmer effect.
class _ShimmerLoadingWidget extends StatefulWidget {
  final bool isDark;
  const _ShimmerLoadingWidget({required this.isDark});

  @override
  State<_ShimmerLoadingWidget> createState() => _ShimmerLoadingWidgetState();
}

class _ShimmerLoadingWidgetState extends State<_ShimmerLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        return _buildSkeletonItem();
      },
    );
  }

  Widget _buildSkeletonItem() {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CircleAvatar placeholder (radius 20 → diameter 40)
          _shimmerCircle(40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + timestamp
                Row(
                  children: [
                    // Name placeholder (width 120, height 14)
                    _shimmerBox(120, 14),
                    const Spacer(),
                    // Timestamp placeholder (width 50, height 10)
                    _shimmerBox(50, 10),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Message preview placeholder (width 200, height 12)
                _shimmerBox(200, 12),
                const SizedBox(height: 8),
                // Row 3: Agent name + badge
                Row(
                  children: [
                    _shimmerBox(80, 10),
                    const Spacer(),
                    // Badge placeholder (width 20, height 20, circle)
                    _shimmerCircle(20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerCircle(double size) {
    final isDark = widget.isDark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value + 1, 0),
          colors: isDark
              ? [Colors.grey.shade800, Colors.grey.shade700, Colors.grey.shade800]
              : [Colors.grey.shade300, Colors.grey.shade100, Colors.grey.shade300],
        ),
      ),
    );
  }

  Widget _shimmerBox(double width, double height, {double borderRadius = 4}) {
    final isDark = widget.isDark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value + 1, 0),
          colors: isDark
              ? [Colors.grey.shade800, Colors.grey.shade700, Colors.grey.shade800]
              : [Colors.grey.shade300, Colors.grey.shade100, Colors.grey.shade300],
        ),
      ),
    );
  }
}
