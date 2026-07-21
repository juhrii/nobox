import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
import '../../../core/model/filter_data_item.dart';
import 'chat_detail_page.dart';
import 'archive_list_page.dart';
import '../../widgets/chat_list_skeleton.dart';
import '../../widgets/connection_status_banner.dart';
import '../../widgets/channel_icon.dart';

// =====================================================================
// FITUR: Halaman Utama Daftar Chat (Inbox)
// FILE: lib/presentation/screens/chat/chat_list_page.dart
// FUNGSI: Menampilkan daftar seluruh percakapan aktif. Menyediakan fitur
//         pencarian, filter (unread, tag, dsb), serta indikator status
//         koneksi WebSocket secara real-time.
// =====================================================================

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

  // FITUR: Infinite Scroll / Pagination
  // FUNGSI: Mendeteksi saat pengguna menggulir ke bawah daftar chat untuk memuat data tambahan (lazy loading).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 200;
    
    final chatProvider = context.read<ChatProvider>();
    final isLoadingMore = chatProvider.isLoadingMore;
    final hasMore = chatProvider.hasMore; 

      // fetchMoreChats() dipanggil untuk meminta data chat berikutnya dari server dengan parameter (kelipatan 20)
    if (isNearBottom && !isLoadingMore && hasMore) {
      chatProvider.fetchMoreChats();
    }
  }

  // FITUR: Filter Tab Chat (Semua, Belum Ditetapkan, dll)
  // FUNGSI: Mengubah filter daftar chat berdasarkan status tab yang dipilih oleh pengguna.
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

  // FITUR: Appbar Mode Seleksi (Bulk Action)
  // FUNGSI: Menampilkan AppBar khusus ketika pengguna memilih satu atau lebih chat, memungkinkan aksi massal seperti Archive atau Pin.
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
        // [ACTION: ARCHIVE_MASSAL] - Ikon untuk arsip masal / multi select
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
                      // [ACTION: ARCHIVE_EXECUTE_MASSAL] - Perulangan untuk mengarsip pesan yang dipilih
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
      // FITUR: Header AppBar (Normal / Mode Pencarian)
      // FUNGSI: Menampilkan judul dan tombol aksi di atas, serta berubah menjadi form input teks saat mode pencarian aktif.
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
                  'assets/nobox.png',
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_alt, color: Colors.white, size: 27),
                      padding: const EdgeInsets.all(8),
                      onPressed: () {
                        _showFilterDialog();
                      },
                    ),
                    if (context.watch<ChatProvider>().hasActiveAdvancedFilters)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                  onSelected: (value) {
                    if (value == 'archived') {
                      Navigator.pushNamed(context, AppRoutes.archivedChats);
                    } else if (value == 'dark_mode') {
                      // Delay theme toggle to next frame so the popup menu
                      // fully closes before the widget tree rebuilds.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          themeProvider.toggleTheme(!isDark);
                        }
                      });
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
                  // FITUR 2: Paging & Pengambilan Chat
                  // FUNGSI: fetchChats() digunakan untuk memanggil 20 percakapan pertama dari server.
                  //         Jika terjadi error (misal 503), tombol ini memanggil fetchChats() lagi (retry).
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

  // FITUR: Dialog Pencarian Bawaan (Cadangan)
  // FUNGSI: Menampilkan input text sederhana dalam sebuah dialog sebagai metode alternatif untuk mencari daftar obrolan aktif.
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

  // FITUR: Dialog Buat Percakapan Baru
  // FUNGSI: Menampilkan popup form (Channel, Akun, Kontak) untuk memulai obrolan baru dengan kontak tertentu atau manual.
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
            // Tarik data saat widget pertama kali dirender
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

            // Helper untuk membuat daftar nama tampilan yang unik dari data API
            List<String> toUniqueNames(List<Map<String, dynamic>> items, List<String> keys) {
              final names = <String>[];
              final seen = <String, int>{};
              for (final item in items) {
                String name = 'Unknown';
                for (final key in keys) {
                  final val = item[key]?.toString();
                  if (val != null && val.isNotEmpty) { name = val; break; }
                }
                // Hilangkan duplikasi: tambahkan (2), (3), dst. untuk nama yang sama
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
              // Pastikan nilai yang dipilih ada di dalam daftar opsi, jika tidak kembalikan ke null
              final safeValue = (value != null && options.contains(value)) ? value : null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchableDropdown<String>(
                        value: safeValue,
                        options: options,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Ekstrak nama unik dari data API untuk menu dropdown
            final channelNames = toUniqueNames(channels, ['Nm', 'Name', 'ChannelName']);
            final accountNames = toUniqueNames(accounts, ['Name', 'AccountName']);
            final contactNames = toUniqueNames(contacts, ['Name']);

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
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
                    const SizedBox(height: 20),

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
                      // Dropdown pilihan jenis obrolan (Private/Group)
                      buildDropdownRow('Chat', selectedChat, ['Private', 'Group'], (val) {
                        if (val != null) setDialogState(() => selectedChat = val);
                      }),

                      // Dropdown pilihan Channel (dari API)
                      buildDropdownRow('Channel', selectedChannel, channelNames, (val) {
                        setDialogState(() => selectedChannel = val);
                      }),

                      // Dropdown pilihan Akun (dari API)
                      buildDropdownRow('Account', selectedAccount, accountNames, (val) {
                        setDialogState(() => selectedAccount = val);
                      }),

                      // Tombol Radio untuk Pilihan Tujuan (To)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 80,
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 0,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'Contact',
                                          groupValue: selectedTo,
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => selectedTo = val);
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const Text('Contact', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'Link',
                                          groupValue: selectedTo,
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => selectedTo = val);
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const Text('Link', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'Manual',
                                          groupValue: selectedTo,
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => selectedTo = val);
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const Text('Manual', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Dropdown pilihan Kontak (dari API) atau input angka secara Manual
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
                                width: 80,
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
                                width: 80,
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

                      const SizedBox(height: 24),

                      // Tombol Batal & Buat Pesan
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
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Temukan ID penerima berdasarkan opsi yang dipilih
                                String? receiver;
                                int? contactId;
                                int? linkId;
                                bool isGroup = selectedChat == 'Group';
                                
                                if (selectedTo == 'Contact' && selectedContact != null) {
                                  final contact = contacts.firstWhere(
                                    (c) => (c['Name']?.toString() ?? '') == selectedContact,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  // Gunakan Id dari LeadLinks (penghubung antara kontak dan channel) sebagai cadangan pencarian
                                  final leadLinks = contact['LeadLinks'];
                                  if (leadLinks is List && leadLinks.isNotEmpty) {
                                    receiver = leadLinks[0]['Id']?.toString();
                                  }
                                  receiver ??= contact['Id']?.toString();
                                  contactId = int.tryParse(contact['Id']?.toString() ?? '');
                                } else if (selectedTo == 'Manual' || selectedTo == 'Link') {
                                  receiver = manualInput;
                                  if (selectedTo == 'Link') {
                                    linkId = int.tryParse(manualInput);
                                  }
                                }

                                if (!isGroup && (receiver == null || receiver.isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Silakan pilih penerima')),
                                  );
                                  return;
                                }

                                // Dapatkan Id akun yang dipilih dalam format integer
                                int accountIdInt = 0;
                                if (selectedAccount != null) {
                                  final idx = accountNames.indexOf(selectedAccount!);
                                  if (idx >= 0 && idx < accounts.length) {
                                    accountIdInt = int.tryParse(accounts[idx]['Id']?.toString() ?? '') ?? 0;
                                  }
                                }

                                // Dapatkan Id channel yang dipilih dalam format integer
                                int channelIdInt = 1;
                                if (selectedChannel != null) {
                                  final idx = channelNames.indexOf(selectedChannel!);
                                  if (idx >= 0 && idx < channels.length) {
                                    channelIdInt = int.tryParse(channels[idx]['Id']?.toString() ?? '') ?? 1;
                                  }
                                }

                                Navigator.pop(dialogContext);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Membuat ruangan obrolan...')),
                                );

                                // Buat ruang obrolan (room) melalui API baru alih-alih sekadar mengirim pesan
                                final result = await chatService.createNewRoom(
                                  accountId: accountIdInt,
                                  channelId: channelIdInt,
                                  contactId: contactId,
                                  linkId: linkId,
                                  manualNumber: selectedTo == 'Manual' ? manualInput : null,
                                  isGroup: isGroup,
                                );

                                if (result['success'] == true) {
                                  // Muat ulang daftar chat dan navigasikan layar ke ruang chat yang baru dibuat
                                  if (mounted) {
                                    // Sesuai kode mentor: Jeda statis lalu fetch ulang paksa
                                    final isManual = manualInput.isNotEmpty;
                                    final delayDuration = isManual 
                                      ? const Duration(seconds: 2)
                                      : const Duration(milliseconds: 1500);
                                    
                                    await Future.delayed(delayDuration);
                                    await context.read<ChatProvider>().fetchChats();

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
                                      String? newRoomIdStr = result['roomId']?.toString();
                                      ChatModel? newChat;
                                      try {
                                        newChat = chats.firstWhere(
                                          (c) {
                                            if (newRoomIdStr != null && newRoomIdStr.isNotEmpty && c.id == newRoomIdStr) return true;
                                            
                                            // Validasi ketat agar tidak salah masuk kamar Telegram/WA
                                            bool isSameChannel = c.chId == channelIdInt.toString();
                                            bool isSameAccount = c.accountId == accountIdInt.toString() || c.accountId.isEmpty;
                                            
                                            if (receiver != null && c.contactId == receiver && isSameChannel && isSameAccount) return true;
                                            if (selectedContact != null && selectedContact!.isNotEmpty && c.sender.toLowerCase().contains(selectedContact!.toLowerCase()) && isSameChannel && isSameAccount) return true;
                                            if (manualInput.isNotEmpty && c.sender.contains(manualInput) && isSameChannel && isSameAccount) return true;
                                            return false;
                                          },
                                        );
                                      } catch (e) {
                                        // Jika tidak ditemukan di 20 list pertama karena belum ada pesan (waktu masih null di server)
                                        newChat = ChatModel(
                                          id: newRoomIdStr ?? '',
                                          contactId: receiver ?? '',
                                          sender: selectedContact?.isNotEmpty == true ? selectedContact! : (manualInput.isNotEmpty ? manualInput : 'New Chat'),
                                          lastMessage: '',
                                          time: DateTime.now().toIso8601String(),
                                          unreadCount: 0,
                                          status: 'Unassigned',
                                          agentName: '',
                                          tags: [],
                                          avatarUrl: null,
                                          lastMessageType: null,
                                          channelName: selectedChannel ?? '',
                                          channelType: selectedChannel ?? '',
                                          isPinned: false,
                                          chId: channelIdInt.toString(),
                                          funnel: '',
                                          isGroup: isGroup,
                                          isBlocked: false,
                                          isLastMessageFromMe: true,
                                          needReply: false,
                                          accountId: accountIdInt.toString(),
                                          ctRealId: receiver ?? '',
                                          link: '',
                                          campaign: '',
                                          deal: '',
                                          groupName: isGroup ? (manualInput.isNotEmpty ? manualInput : 'Group') : '',
                                          groupId: isGroup ? (receiver ?? '') : '',
                                        );
                                        // Masukkan ke daftar lokal agar langsung terlihat
                                        context.read<ChatProvider>().insertLocalChat(newChat);
                                      }
                                      
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatDetailPage(chat: newChat),
                                        ),
                                      );
                                      if (mounted) {
                                        context.read<ChatProvider>().refreshFirstPage();
                                      }
                                    }
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal membuat ruangan: ${result['error']}')),
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

  // FITUR: Tile Akses Arsip
  // FUNGSI: Menampilkan baris di atas daftar chat untuk mengakses halaman Arsip, lengkap dengan jumlah (badge) chat yang saat ini diarsipkan.
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

  // FITUR: Dialog Konfirmasi Keluar (Logout)
  // FUNGSI: Menampilkan popup peringatan dan menghapus cache lokal (provider) sebelum membawa pengguna kembali ke layar login.
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
              // Bersihkan cache (tags, funnels, chatrooms) sebelum logout agar tidak bocor ke sesi login akun berikutnya
              context.read<ChatProvider>().clearChatDataForAccountSwitch();
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
  // FITUR: Skeleton Loading (Pagination)
  // FUNGSI: Menampilkan animasi kerangka memuat (shimmer effect) di bagian bawah daftar chat saat aplikasi sedang menarik data halaman berikutnya.
  Widget _buildLoadingMoreSkeleton(bool isDark) {
    return _ShimmerLoadingWidget(isDark: isDark);
  }

  // FITUR: Status Badge (Assigned/Resolved/dll)
  // FUNGSI: Merender label kecil di kanan bawah chat tile berdasarkan status tiket obrolan, dengan warna yang disesuaikan.
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
            onTap: () async {
              if (_selectedChats.isNotEmpty) {
                setState(() {
                  if (isSelected) _selectedChats.remove(chat.id);
                  else _selectedChats.add(chat.id);
                });
                return;
              }
              chatProvider.markAsRead(chat.id);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailPage(chat: chat),
                ),
              );
              
              if (mounted) {
                // Refresh list percakapan setelah kembali dari ruang chat 
                // untuk memastikan last message tersinkronisasi akurat.
                chatProvider.refreshFirstPage();
              }
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
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Avatar ──
                    Align(
                      alignment: Alignment.topCenter,
                      child: _selectedChats.isNotEmpty
                          ? Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                                size: 28,
                              ),
                            )
                          : CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                                  ? NetworkImage(chat.avatarUrl!)
                                  : null,
                              child: chat.avatarUrl == null || chat.avatarUrl!.isEmpty
                                  // Logika pengecekan: Jika chat adalah Group, gunakan ikon grup berombongan (Icons.group)
                                  // Jika personal, gunakan ikon orang tunggal (Icons.person)
                                  ? Icon(
                                      chat.isGroup ? Icons.groups : Icons.person,
                                      color: Colors.grey.shade600,
                                      size: 28,
                                    )
                                  : null,
                            ),
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

                    // Row 4: Channel Icon and Name
                    if (chat.channelName.isNotEmpty && chat.channelName != 'Not Found') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ChannelIcon(chId: chat.chId, channelName: '${chat.channelType} ${chat.channelName}', size: 14),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                          if (chat.isBlocked) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.person_off, size: 14, color: Colors.red),
                          ],
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
                    ],
                  ),
                  
                  // Status badge
                  _buildStatusBadge(chat.status),
                ],
              ),
            ],
          ),
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

  // FITUR: Preview Pesan Terakhir (Indikator Warna & Tipe)
  // FUNGSI: Menampilkan cuplikan pesan terakhir di daftar chat, memberikan warna khusus (merah jika butuh balasan dari pelanggan), dan membedakan ikon lampiran.
  Widget _buildLastMessageRow(ChatModel chat, bool isDark) {
    // Logika warna berdasarkan pengirim (menggunakan properti needReply dari API):
    // Jika needReply = true -> Pesan butuh balasan (dari customer) -> Merah
    // Jika needReply = false -> Pesan tidak butuh balasan (dari agen) -> Hitam/Warna Tema
    final bool isFromCustomer = chat.needReply;
    
    // Jika dari customer = Merah. Jika dari agen = Hitam/Grey.
    final Color messageColor = isFromCustomer 
        ? Colors.red 
        : (isDark ? Colors.grey.shade400 : Colors.black87);
    
    String displayMessage = chat.lastMessage;
    if (displayMessage.trim().toLowerCase() == 'document(empty)') {
      displayMessage = '';
    }
    final trimmedMsg = displayMessage.trim();
    bool parsedAsMedia = false;
    
    // FIX: Tangani label manual (fallback) terlebih dahulu sebelum JSON parsing.
    // Jika lastMessage diketik paksa secara lokal (misal: "🎤 Pesan Suara" saat merekam),
    // langsung atur ke Voice Note agar tidak tertimpa oleh chat.lastMessageType ("Document") yang usang.
    final lowerTrimmed = trimmedMsg.toLowerCase();
    final exactAudioLabels = ['voice note', '🎵 voice note', 'pesan suara', '🎤 pesan suara', 'audio', 'voice(empty)', 'voice (empty)'];
    final exactPhotoLabels = ['photo', '📷 photo', 'image', 'foto', '📷 foto'];
    final exactVideoLabels = ['video', '🎥 video', '🎬 video'];

    if (lowerTrimmed.contains('sticker')) {
      displayMessage = '🌟 Sticker';
      parsedAsMedia = true;
    } else if (exactAudioLabels.contains(lowerTrimmed)) {
      displayMessage = '🎤 Pesan Suara';
      parsedAsMedia = true;
    } else if (exactPhotoLabels.contains(lowerTrimmed)) {
      displayMessage = '📷 Foto';
      parsedAsMedia = true;
    } else if (exactVideoLabels.contains(lowerTrimmed)) {
      displayMessage = '🎥 Video';
      parsedAsMedia = true;
    }

    // 1. Coba parse JSON terlebih dahulu (karena prioritas detail media dari JSON lebih akurat daripada lastMessageType)
    if (!parsedAsMedia && (trimmedMsg.startsWith('{') || trimmedMsg.startsWith('['))) {
      try {
        final decoded = jsonDecode(trimmedMsg);
        final fileMap = decoded is List ? (decoded.isNotEmpty ? decoded.first : {}) : decoded;
        
        if (fileMap is Map) {
          // EXTRACT NESTED MAP IF PRESENT (Some backend payloads wrap the file details)
          Map targetMap = fileMap;
          if (targetMap['File'] is String && (targetMap['File'].toString().startsWith('{') || targetMap['File'].toString().startsWith('['))) {
             try { 
               final decodedFile = jsonDecode(targetMap['File']); 
               if (decodedFile is List && decodedFile.isNotEmpty) targetMap = decodedFile.first;
               else if (decodedFile is Map) targetMap = decodedFile;
             } catch (_) {}
          } else if (targetMap['Files'] is List && (targetMap['Files'] as List).isNotEmpty) {
             final firstItem = targetMap['Files'].first;
             if (firstItem is Map) {
               targetMap = firstItem;
             } else if (firstItem is String) {
               // If it's just a string, it might be the filename itself!
               targetMap = {'File': firstItem, 'Type': targetMap['Type'] ?? targetMap['type'] ?? fileMap['Type']};
             }
          } else if (targetMap['Files'] is String && (targetMap['Files'].toString().startsWith('{') || targetMap['Files'].toString().startsWith('['))) {
             try { 
               final decodedFiles = jsonDecode(targetMap['Files']);
               if (decodedFiles is List && decodedFiles.isNotEmpty) targetMap = decodedFiles.first;
               else if (decodedFiles is Map) targetMap = decodedFiles;
             } catch (_) {}
          } else if (targetMap['Msg'] is String && (targetMap['Msg'].toString().startsWith('{') || targetMap['Msg'].toString().startsWith('['))) {
             try { 
               final decodedMsg = jsonDecode(targetMap['Msg']); 
               if (decodedMsg is List && decodedMsg.isNotEmpty) targetMap = decodedMsg.first;
               else if (decodedMsg is Map) targetMap = decodedMsg;
             } catch (_) {}
          }

          // FIX: Buat pengecekan key JSON menjadi case-insensitive dan tangani tipe string
          final typeVal = targetMap['Type']?.toString() ?? targetMap['type']?.toString() ?? fileMap['Type']?.toString() ?? '';
          
          final isPtt = targetMap['Ptt'] == true || targetMap['IsPtt'] == true || targetMap['ptt'] == true || targetMap['isPtt'] == true ||
                        targetMap['Ptt']?.toString().toLowerCase() == 'true' || targetMap['ptt']?.toString().toLowerCase() == 'true';
                        
          final filename = targetMap['Filename']?.toString().toLowerCase() ?? 
                           targetMap['filename']?.toString().toLowerCase() ?? 
                           targetMap['File']?.toString().toLowerCase() ?? 
                           targetMap['file']?.toString().toLowerCase() ?? 
                           targetMap['url']?.toString().toLowerCase() ?? 
                           targetMap['Url']?.toString().toLowerCase() ?? '';
                           
          final originalName = targetMap['OriginalName']?.toString().toLowerCase() ?? targetMap['originalname']?.toString().toLowerCase() ?? '';
          final caption = targetMap['Caption']?.toString() ?? targetMap['caption']?.toString() ?? '';
          
          final isDocument = typeVal == '5';

          final isAudio = isPtt || typeVal == '2' || 
                         (!isDocument && (['.ogg', '.oga', '.mp3', '.wav', '.m4a', '.opus', '.aac', '.weba', '.amr'].any((ext) => filename.contains(ext) || originalName.contains(ext)) ||
                          originalName.contains('voice note') || originalName.contains('voice_') || filename.contains('voice_')));
          
          final isImage = typeVal == '3' || 
                         (!isDocument && ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((ext) => filename.contains(ext) || originalName.contains(ext)));
                         
          final isAnimatedSticker = typeVal == '16' || (!isDocument && ['.webm', '.tgs'].any((ext) => filename.contains(ext) || originalName.contains(ext)));
          
          final isVideo = (typeVal == '4' && !isAnimatedSticker) || 
                         (!isDocument && !isAnimatedSticker && ['.mp4', '.avi', '.mov', '.3gp', '.mkv'].any((ext) => filename.contains(ext) || originalName.contains(ext)));
                         
          final isLocation = typeVal == '15' || typeVal == '11' || trimmedMsg.toLowerCase().contains('"lat":');
          final isContact = typeVal == '14' || typeVal == '10';

          if (isDocument) {
            String docName = 'Dokumen';
            if (originalName.isNotEmpty) {
              docName = targetMap['OriginalName']?.toString() ?? targetMap['originalname']?.toString() ?? 'Dokumen';
            } else if (filename.isNotEmpty) {
              docName = (targetMap['Filename']?.toString() ?? targetMap['url']?.toString() ?? 'Dokumen').split('/').last;
            }
            displayMessage = '📄 $docName';
            parsedAsMedia = true;
          } else if (isAudio) {
            displayMessage = '🎤 Pesan Suara';
            parsedAsMedia = true;
          } else if (isImage) {
            displayMessage = '📷 Foto${caption.isNotEmpty ? ' $caption' : ''}';
            parsedAsMedia = true;
          } else if (isAnimatedSticker) {
            displayMessage = '🌟 Sticker';
            parsedAsMedia = true;
          } else if (isVideo) {
            displayMessage = '🎥 Video${caption.isNotEmpty ? ' $caption' : ''}';
            parsedAsMedia = true;
          } else if (isLocation) {
            displayMessage = '📍 Lokasi';
            parsedAsMedia = true;
          } else if (isContact) {
            displayMessage = '👤 Kontak';
            parsedAsMedia = true;
          } else if (filename.isNotEmpty || originalName.isNotEmpty) {
            // Cek apakah backend secara eksplisit memberitahu tipe media di lastMessageType
            final overrideType = chat.lastMessageType?.toLowerCase() ?? '';
            if (overrideType.contains('voice note') || overrideType.contains('audio')) {
              displayMessage = '🎤 Pesan Suara';
            } else if (overrideType.contains('image') || overrideType.contains('photo')) {
              displayMessage = '📷 Foto${caption.isNotEmpty ? ' $caption' : ''}';
            } else if (overrideType.contains('video')) {
              displayMessage = '🎥 Video${caption.isNotEmpty ? ' $caption' : ''}';
            } else {
              String docName = 'Lampiran';
              if (originalName.isNotEmpty) {
                docName = targetMap['OriginalName']?.toString() ?? targetMap['originalname']?.toString() ?? 'Lampiran';
              } else if (filename.isNotEmpty) {
                docName = (targetMap['Filename']?.toString() ?? targetMap['url']?.toString() ?? 'Lampiran').split('/').last;
              }
              
              if (docName.toLowerCase().contains('document(empty)')) {
                 final rawText = targetMap['Msg']?.toString() ?? targetMap['Body']?.toString() ?? targetMap['Message']?.toString() ?? targetMap['Content']?.toString() ?? '';
                 if (rawText.isNotEmpty && !rawText.startsWith('{') && !rawText.startsWith('[')) {
                    displayMessage = rawText;
                 } else {
                    displayMessage = '📎 Lampiran';
                 }
                 parsedAsMedia = true; // Set to true so it doesn't get overridden by fallback logic
              } else {
                // DEBUG: Tampilkan isi mentah dari pesan agar kita bisa melihat bentuk data JSON-nya
                if (trimmedMsg.isNotEmpty) {
                  final preview = trimmedMsg.length > 35 ? '${trimmedMsg.substring(0, 35)}...' : trimmedMsg;
                  displayMessage = '📎 RAW: $preview';
                } else {
                  displayMessage = '📎 $docName';
                }
                parsedAsMedia = true;
              }
            } // Close the `else` block from line 1495
            parsedAsMedia = true;
          }
        }
      } catch (_) {
        // Abaikan error parse, mungkin bukan JSON media
      }
    }
    
    // 2. Jika tidak berhasil diparse sebagai media JSON secara spesifik, cek lastMessageType dari backend
    if (!parsedAsMedia && chat.lastMessageType != null && chat.lastMessageType!.isNotEmpty) {
      final overrideType = chat.lastMessageType!.toLowerCase();
      
      if (overrideType.contains('voice note') || overrideType.contains('audio') || overrideType == '2') {
        displayMessage = '🎤 Pesan Suara';
      } else if (overrideType.contains('image') || overrideType.contains('photo') || overrideType == '3') {
        final cleaned = displayMessage.replaceAll('📷', '').replaceAll('Photo', '').replaceAll('Foto', '').trim();
        displayMessage = '📷 Foto${cleaned.isNotEmpty ? ' $cleaned' : ''}';
      } else if (overrideType.contains('video') || overrideType == '4') {
        final cleaned = displayMessage.replaceAll('🎥', '').replaceAll('📹', '').replaceAll('Video', '').trim();
        if (displayMessage.toLowerCase().contains('.webm') || displayMessage.toLowerCase().contains('.tgs') || displayMessage.toLowerCase().contains('sticker')) {
          displayMessage = '🌟 Sticker';
        } else {
          displayMessage = '🎥 Video${cleaned.isNotEmpty ? ' $cleaned' : ''}';
        }
      } else if (overrideType == '16' || overrideType.contains('sticker')) {
        displayMessage = '🌟 Sticker';
      } else if (overrideType.contains('document') || overrideType.contains('file') || overrideType == '5') {
        if (displayMessage.contains('📎') || displayMessage.contains('📁') || displayMessage.contains('📄')) {
          // sudah ada emoji
        } else if (displayMessage.isEmpty) {
          final isTelegram = chat.chId == '2' || chat.channelType.toLowerCase().contains('telegram') || chat.channelName.toLowerCase().contains('telegram');
          if (isTelegram) {
            displayMessage = '🎤 Pesan Suara'; // HACK: Asumsi server NoBox untuk file .ogg Telegram tanpa caption
          } else {
            displayMessage = '📎 Lampiran';
          }
        } else {
          final preview = trimmedMsg.length > 35 ? '${trimmedMsg.substring(0, 35)}...' : trimmedMsg;
          displayMessage = '📎 $preview';
        }
      } else if (overrideType == '15' || overrideType == '11' || overrideType.contains('location')) {
        displayMessage = '📍 Lokasi';
      } else if (overrideType == '14' || overrideType == '10' || overrideType.contains('contact')) {
        displayMessage = '👤 Kontak';
      } else if (overrideType.contains('unsupported')) {
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
      } else if (overrideType == '1' || overrideType == 'text') {
        // Teks biasa, abaikan
      } else {
        // Fallback untuk tipe lain yang tidak dikenal
        displayMessage = '🌟 ${chat.lastMessageType}${displayMessage.isNotEmpty ? ' $displayMessage' : ''}';
      }
      
      if (overrideType != '1' && overrideType != 'text') {
        parsedAsMedia = true;
      }
    }
    
    // 3. Fallback jika string kosong dan bukan media
    if (!parsedAsMedia && displayMessage.isEmpty) {
      final isTelegram = chat.chId == '2' || chat.channelType.toLowerCase().contains('telegram') || chat.channelName.toLowerCase().contains('telegram');
      if (isTelegram) {
        displayMessage = '🎤 Pesan Suara'; // ULTIMATE HACK: Any empty unrecognized message from Telegram is a Voice Note
      } else {
        displayMessage = '📎 Lampiran';
      }
    }

    if (!parsedAsMedia && (displayMessage == 'Document' || displayMessage == '📄 Document' || displayMessage == '📄 File' || displayMessage == '📎 Lampiran')) {
       displayMessage = '📎 Lampiran';
    }

    // 4. Deteksi nama file mentah (non-JSON) berdasarkan ekstensi/pola nama
    bool isGenericAttachment = displayMessage.startsWith('📎') || displayMessage == 'Lampiran' || displayMessage.contains('RAW:');
    bool isDocumentAlready = displayMessage.startsWith('📄');
    
    if (!parsedAsMedia || isGenericAttachment || isDocumentAlready) {
      final lower = displayMessage.toLowerCase().replaceAll('📎', '').replaceAll('📄', '').replaceAll('raw:', '').trim();
      
      // Jika sudah ditandai sebagai dokumen (📄), TETAP jadikan Dokumen terlepas dari ekstensinya!
      if (isDocumentAlready) {
        // Tampilkan nama aslinya jika ada (tapi dibersihkan), atau cukup "Dokumen" jika berantakan
        if (lower.contains('img-') || lower.contains('vid-') || lower.contains('wa00')) {
           displayMessage = '📄 Dokumen';
        } else {
           // Pertahankan nama file asli jika dirasa rapi (misal: "📄 Laporan.pdf")
           displayMessage = displayMessage;
        }
        parsedAsMedia = true;
      }
      // Deteksi ekstensi gambar
      else if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].any((ext) => lower.endsWith(ext)) || 
          lower.startsWith('img-') || lower.startsWith('img_') || lower.startsWith('photo')) {
        displayMessage = '📷 Foto';
        parsedAsMedia = true;
      }
      // Deteksi stiker animasi (.webm, .tgs)
      else if (['.webm', '.tgs'].any((ext) => lower.endsWith(ext))) {
        displayMessage = '🌟 Animated Sticker';
        parsedAsMedia = true;
      }
      // Deteksi ekstensi video
      else if (['.mp4', '.avi', '.mov', '.3gp', '.mkv'].any((ext) => lower.endsWith(ext)) || 
               lower.startsWith('vid-') || lower.startsWith('vid_')) {
        displayMessage = '🎥 Video';
        parsedAsMedia = true;
      }
      // Deteksi ekstensi audio/voice note
      else if (['.ogg', '.opus', '.mp3', '.wav', '.m4a', '.aac', '.amr', '.weba'].any((ext) => lower.endsWith(ext)) || 
               lower.startsWith('voice_') || lower.startsWith('ptt-') || lower.startsWith('aud-')) {
        displayMessage = '🎤 Pesan Suara';
        parsedAsMedia = true;
      }
      // Deteksi ekstensi dokumen
      else if (['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv', '.zip', '.rar'].any((ext) => lower.endsWith(ext))) {
        displayMessage = '📄 Dokumen';
        parsedAsMedia = true;
      }
      // Jika ada ekstensi file apapun (generic file detection)
      else if (RegExp(r'\.[a-zA-Z0-9]{2,5}$').hasMatch(lower) && !lower.contains(' ') && lower.length < 100) {
        displayMessage = '📎 Lampiran';
        parsedAsMedia = true;
      }
    }

    return Text(
      displayMessage,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        color: messageColor,
      ),
    );
  }

  // FITUR: Format Waktu Relatif
  // FUNGSI: Mengonversi waktu standar UTC dari server menjadi format string yang ramah pembaca untuk menampilkan jam atau tanggal obrolan terakhir.
  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      String timeString = rawTime;
      if (!timeString.endsWith('Z') && !timeString.contains('+') && timeString.length >= 19) {
        timeString += 'Z';
      }
      final dt = DateTime.parse(timeString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      // If not parseable, return as-is (legacy format)
      return rawTime;
    }
  }

  // FITUR: Dialog Filter Lanjutan (Advanced Filter)
  // FUNGSI: Membuka modal popup besar yang memuat API Master Data (Campaign, Funnel, Label, dll) untuk memfilter daftar obrolan secara presisi.
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
    List<String> selectedAccountIds = List.from(provider.filterAccountIds);
    String? selectedContactId = provider.filterContact;
    String? selectedLinkId = provider.filterLink;
    String? selectedGroupId = provider.filterGroup;
    String? selectedCampaignId = provider.filterCampaign;
    String? selectedFunnelId = provider.filterFunnel;
    String? selectedDealId = provider.filterDeal;
    String? selectedTagsId = provider.filterTags;
    String? selectedHumanAgentId = provider.filterHumanAgent;

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: Future.wait([
            provider.getChannelsResponse(),
            provider.getAccountsResponse(),
            provider.getContactsResponse(),
            provider.getGroupsResponse(),
            provider.getCampaignsResponse(),
            provider.getFunnels(),
            provider.getDealsResponse(),
            provider.getTags(),
            provider.getAgents(),
            provider.getLinksResponse(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Extract lists gracefully into Models
            final channelsRaw = snapshot.data?[0] as ApiResponse<List<Map<String, dynamic>>>?;
            // FIXME: Jangan pakai Nm dari Master/Channel/List (misal: "SellerTokopedia.com")
            // karena channelType disimpan sebagai Account.Code (misal: "TokopediaCom").
            // Ambil opsi channel DARI Account list Code agar matching pasti benar.

            final accountsRaw = snapshot.data?[1] as ApiResponse<List<Map<String, dynamic>>>?;
            final accountList = accountsRaw?.data ?? [];

            // Derive unique channel codes from account list (e.g., 'WhatsApp', 'Telegram', 'TokopediaCom')
            // Also build a display name map: Code -> prettier name
            final channelCodeToName = <String, String>{};
            for (final acc in accountList) {
              final code = acc['Code']?.toString() ?? '';
              if (code.isEmpty) continue;
              // Try to get a prettier name from Master/Channel/List via Kd matching
              final masterMatch = channelsRaw?.data?.firstWhere(
                (ch) => (ch['Kd']?.toString() ?? '') == code,
                orElse: () => <String, dynamic>{},
              );
              final displayName = (masterMatch != null && masterMatch.isNotEmpty)
                  ? (masterMatch['Nm']?.toString() ?? code)
                  : code;
              channelCodeToName[code] = displayName;
            }
            // channels list = unique codes (used as filter value)
            final channels = channelCodeToName.keys.toList();

            final contactsRaw = snapshot.data?[2] as ApiResponse<List<Map<String, dynamic>>>?;
            final contacts = contactsRaw?.data?.map((e) => ContactItem.fromJson(e)).toList() ?? [];

            final groupsRaw = snapshot.data?[3] as ApiResponse<List<Map<String, dynamic>>>?;
            final groups = groupsRaw?.data?.map((e) => GroupItem.fromJson(e)).toList() ?? [];

            final campaignsRaw = snapshot.data?[4] as ApiResponse<List<Map<String, dynamic>>>?;
            final campaigns = campaignsRaw?.data?.map((e) => CampaignItem.fromJson(e)).toList() ?? [];

            final funnelsRaw = snapshot.data?[5] as List<Map<String, dynamic>>?;
            final funnels = funnelsRaw?.map((e) => FunnelItem.fromJson(e)).toList() ?? [];

            final dealsRaw = snapshot.data?[6] as ApiResponse<List<Map<String, dynamic>>>?;
            final deals = dealsRaw?.data?.map((e) => DealItem.fromJson(e)).toList() ?? [];

            final tagsRaw = snapshot.data?[7] as List<Map<String, dynamic>>?;
            final tags = tagsRaw?.map((e) => TagItem.fromJson(e)).toList() ?? [];

            final agentsRaw = snapshot.data?[8] as List<Map<String, dynamic>>?;
            final agents = agentsRaw?.map((e) => HumanAgentItem.fromJson(e)).toList() ?? [];

            final linksRaw = snapshot.data?[9] as ApiResponse<List<Map<String, dynamic>>>?;
            final links = linksRaw?.data?.map((e) => LinkItem.fromJson(e)).toList() ?? [];

            if (selectedChannel != null && !channels.contains(selectedChannel) && selectedChannel != '--select--') channels.add(selectedChannel!);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final themeProvider = Provider.of<ThemeProvider>(context);
                final isDark = themeProvider.isDarkMode;

                Widget buildDropdownRow<T>(
                  String label, 
                  T? value, 
                  List<T> options, 
                  ValueChanged<T?> onChanged,
                  {String Function(T)? itemAsString}
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppTheme.darkTextPrimary : Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SearchableDropdown<T>(
                            value: value,
                            options: options,
                            onChanged: onChanged,
                            itemAsString: itemAsString,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Dialog(
                  backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.025,
                    vertical: MediaQuery.of(context).size.height * 0.1,
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filter Conversation',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.close,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                        ),

                        const SizedBox(height: 20),

                        // Apply & Reset buttons
                        Row(
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
                                    accountIds: selectedAccountIds,
                                    contact: selectedContactId,
                                    link: selectedLinkId,
                                    group: selectedGroupId,
                                    campaign: selectedCampaignId,
                                    funnel: selectedFunnelId,
                                    deal: selectedDealId,
                                    tags: selectedTagsId,
                                    humanAgent: selectedHumanAgentId,
                                  );
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.filter_alt, size: 16),
                                label: const Text('Apply'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    selectedAccountIds = [];
                                    selectedContactId = null;
                                    selectedLinkId = null;
                                    selectedGroupId = null;
                                    selectedCampaignId = null;
                                    selectedFunnelId = null;
                                    selectedDealId = null;
                                    selectedTagsId = null;
                                    selectedHumanAgentId = null;
                                  });
                                  provider.resetFilters();
                                },
                                icon: Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: isDark ? Colors.white : AppTheme.primaryColor,
                                ),
                                label: Text(
                                  'Reset',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                        ),

                        const SizedBox(height: 20),

                        // Scrollable filter rows
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                buildDropdownRow('Status', selectedStatus, ['Assigned', 'Unassigned', 'Resolved'], (val) {
                                  setDialogState(() => selectedStatus = val);
                                }),
                                buildDropdownRow('Is Mute Ai Agent', selectedMuteAi, ['Active', 'Inactive'], (val) {
                                  setDialogState(() => selectedMuteAi = val);
                                }),
                                buildDropdownRow('Read Status', selectedReadStatus, ['Is Read', 'Unread'], (val) {
                                  setDialogState(() => selectedReadStatus = val);
                                }),
                                buildDropdownRow('Channel', selectedChannel, channels.isEmpty ? ['WhatsApp', 'Telegram', 'TikTok', 'Shopee', 'Tokopedia'] : channels, (val) {
                                  setDialogState(() => selectedChannel = val);
                                }, itemAsString: (code) => channelCodeToName[code] ?? code),
                                buildDropdownRow('Chat', selectedChat, ['Private', 'Group'], (val) {
                                  setDialogState(() => selectedChat = val);
                                }),
                                 Padding(
                                   padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          'Account',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppTheme.darkTextPrimary : Colors.black,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) {
                                                return StatefulBuilder(
                                                  builder: (context, setMultiSelectState) {
                                                    return AlertDialog(
                                                      title: const Text('Pilih Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                                      content: accountList.isEmpty
                                                          ? const Padding(padding: EdgeInsets.all(16), child: Text("No accounts available"))
                                                          : SingleChildScrollView(
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: accountList.map((account) {
                                                                  final id = account['Id']?.toString() ?? '';
                                                                  final name = account['Name']?.toString() ?? account['Nm']?.toString() ?? 'Unknown';
                                                                  final isChecked = selectedAccountIds.contains(id);

                                                                  return CheckboxListTile(
                                                                    title: Text(name, style: const TextStyle(fontSize: 14)),
                                                                    value: isChecked,
                                                                    controlAffinity: ListTileControlAffinity.leading,
                                                                    contentPadding: EdgeInsets.zero,
                                                                    visualDensity: VisualDensity.compact,
                                                                    onChanged: (bool? value) {
                                                                      setMultiSelectState(() {
                                                                        if (value == true) {
                                                                          selectedAccountIds.add(id);
                                                                        } else {
                                                                          selectedAccountIds.remove(id);
                                                                        }
                                                                      });
                                                                      setDialogState(() {});
                                                                    },
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx),
                                                          child: const Text('Tutup'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              color: isDark ? AppTheme.darkSurface : Colors.white,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    selectedAccountIds.isEmpty 
                                                      ? '--select--' 
                                                      : '${selectedAccountIds.length} Selected',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isDark ? AppTheme.darkTextPrimary : Colors.black,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade600,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                buildDropdownRow<ContactItem>(
                                  'Contact', 
                                  contacts.where((e) => e.id == selectedContactId).isEmpty ? null : contacts.firstWhere((e) => e.id == selectedContactId), 
                                  contacts.isEmpty ? <ContactItem>[] : contacts, 
                                  (val) => setDialogState(() => selectedContactId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<LinkItem>(
                                  'Link', 
                                  links.where((e) => e.id == selectedLinkId).isEmpty ? null : links.firstWhere((e) => e.id == selectedLinkId), 
                                  links.isEmpty ? <LinkItem>[] : links, 
                                  (val) => setDialogState(() => selectedLinkId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<GroupItem>(
                                  'Group', 
                                  groups.where((e) => e.id == selectedGroupId).isEmpty ? null : groups.firstWhere((e) => e.id == selectedGroupId), 
                                  groups.isEmpty ? <GroupItem>[] : groups, 
                                  (val) => setDialogState(() => selectedGroupId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<CampaignItem>(
                                  'Campaign', 
                                  campaigns.where((e) => e.id == selectedCampaignId).isEmpty ? null : campaigns.firstWhere((e) => e.id == selectedCampaignId), 
                                  campaigns.isEmpty ? <CampaignItem>[] : campaigns, 
                                  (val) => setDialogState(() => selectedCampaignId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<FunnelItem>(
                                  'Funnel', 
                                  funnels.where((e) => e.id == selectedFunnelId).isEmpty ? null : funnels.firstWhere((e) => e.id == selectedFunnelId), 
                                  funnels.isEmpty ? <FunnelItem>[] : funnels, 
                                  (val) => setDialogState(() => selectedFunnelId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<DealItem>(
                                  'Deal', 
                                  deals.where((e) => e.id == selectedDealId).isEmpty ? null : deals.firstWhere((e) => e.id == selectedDealId), 
                                  deals.isEmpty ? <DealItem>[] : deals, 
                                  (val) => setDialogState(() => selectedDealId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<TagItem>(
                                  'Tags', 
                                  tags.where((e) => e.id == selectedTagsId).isEmpty ? null : tags.firstWhere((e) => e.id == selectedTagsId), 
                                  tags.isEmpty ? <TagItem>[] : tags, 
                                  (val) => setDialogState(() => selectedTagsId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                buildDropdownRow<HumanAgentItem>(
                                  'Human Agents', 
                                  agents.where((e) => e.id == selectedHumanAgentId).isEmpty ? null : agents.firstWhere((e) => e.id == selectedHumanAgentId), 
                                  agents.isEmpty ? <HumanAgentItem>[] : agents, 
                                  (val) => setDialogState(() => selectedHumanAgentId = val?.id),
                                  itemAsString: (item) => item.name,
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

  // FITUR: Bottom Sheet Opsi Chat (Pin, Archive, Assign)
  // FUNGSI: Menampilkan menu pop-up di bawah layar ketika sebuah chat ditekan lama, memungkinkan agen untuk menyematkan, mengarsipkan, atau mengubah status tiket obrolan (Assign/Resolve).
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
          // [ACTION: ARCHIVE_SINGLE] - Di gunakan agar user ketika memencet log press akan muncul opo up dari
          // bawah layar lalu memilih opsi archive (arsipkan chat)
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
                        // [ACTION: ARCHIVE_EXECUTE_SINGLE] - Ketika pengguna memencet konformasi maka sistem akan mengeksekusi kode chatProvider.toggleArchive
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
// FITUR: Wrapper Widget Chat Tile
// FUNGSI: Membungkus chat tile individu. (Logika swipe sudah dinonaktifkan atas permintaan bisnis, namun widget tetap dipertahankan untuk kompatibilitas struktur).
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

// FITUR: Animasi Shimmer Loading
// FUNGSI: Menampilkan 3 kerangka (skeleton) berbentuk chat tile dengan efek mengkilap (shimmer) saat memuat daftar obrolan berikutnya via pagination (infinite scroll).
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
