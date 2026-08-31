import 'package:flutter/material.dart';
import '../../../core/model/message.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../chat/chat_list_page.dart';
import '../chat/chat_detail_page.dart';

// =====================================================================
// FITUR: Halaman Utama Responsif (Master-Detail)
// FILE: lib/presentation/screens/home/responsive_chat_home.dart
// FUNGSI: Mengelola tata letak layar berdasarkan lebar perangkat.
//         - Desktop/Tablet (> 800px): Kiri Daftar Chat, Kanan Ruang Chat.
//         - Mobile (<= 800px): Tumpukan navigasi biasa (hanya Daftar Chat).
// =====================================================================

class ResponsiveChatHome extends StatefulWidget {
  const ResponsiveChatHome({super.key});

  @override
  State<ResponsiveChatHome> createState() => _ResponsiveChatHomeState();
}

class _ResponsiveChatHomeState extends State<ResponsiveChatHome> {
  ChatModel? _selectedChat;

  void _handleChatSelected(ChatModel chat) {
    setState(() {
      _selectedChat = chat;
    });
  }

  Widget _buildEmptyDetail(BuildContext context, bool isDarkMode) {
    return Container(
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'NoBox Chat',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih obrolan untuk mulai mengirim pesan',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          // Desktop / Tablet Mode: Master-Detail Layout
          return Scaffold(
            body: Row(
              children: [
                // Kiri: Daftar Chat (Master)
                SizedBox(
                  width: 350,
                  child: ChatListPage(
                    onChatSelected: _handleChatSelected,
                    selectedChatId: _selectedChat?.id,
                  ),
                ),
                // Pemisah Visual
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                ),
                // Kanan: Ruang Obrolan (Detail)
                Expanded(
                  child: _selectedChat == null
                      ? _buildEmptyDetail(context, isDarkMode)
                      // Ganti key agar setiap kali ganti obrolan, state ChatDetailPage ter-reset murni
                      : ChatDetailPage(
                          key: ValueKey(_selectedChat!.id),
                          chat: _selectedChat,
                        ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Mode: Hanya Daftar Chat
          return const ChatListPage(
            onChatSelected: null,
            selectedChatId: null,
          );
        }
      },
    );
  }
}
