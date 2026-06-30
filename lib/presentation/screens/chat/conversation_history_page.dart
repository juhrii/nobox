import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/model/conversation.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/channel_icon.dart';
import 'chat_detail_page.dart';

// =====================================================================
// FITUR: Riwayat Percakapan (History)
// FILE: lib/presentation/screens/chat/conversation_history_page.dart
// FUNGSI: Menampilkan histori obrolan atau sesi-sesi sebelumnya dengan 
//         kontak tertentu dari berbagai channel (jika digabungkan).
// =====================================================================

class ConversationHistoryPage extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String? contactImage;

  const ConversationHistoryPage({
    super.key,
    required this.contactId,
    required this.contactName,
    this.contactImage,
  });

  @override
  State<ConversationHistoryPage> createState() => _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  final ChatService _chatService = ChatService();
  List<Conversation> _historyRooms = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversationHistory();
  }

  // FITUR: Memuat Riwayat Percakapan (API Call)
  // FUNGSI: Mengambil data daftar sesi obrolan (history) dari server berdasarkan ID kontak yang saat ini sedang dibuka.
  Future<void> _loadConversationHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _chatService.getConversationHistory(widget.contactId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isError) {
          _errorMessage = response.error ?? 'Failed to load conversation history';
        } else {
          _historyRooms = response.data ?? [];
        }
      });
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // FITUR: Format Waktu Relatif
  // FUNGSI: Mengonversi format waktu standar UTC dari server menjadi string ramah pengguna (contoh: "10:30", "Yesterday", "Mon").
  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      String timeString = rawTime;
      if (!timeString.endsWith('Z') && !timeString.contains('+') && timeString.length >= 19) {
        timeString += 'Z';
      }
      final dt = DateTime.parse(timeString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (diff.inDays == 0 && now.day == dt.day) {
        return timeStr;
      } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
      }
    } catch (_) {
      return rawTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation History',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              widget.contactName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildBody(isDarkMode),
      ),
    );
  }

  // FITUR: Tampilan Kondisional (State Management UI)
  // FUNGSI: Me-render tampilan yang berbeda berdasarkan status data (sedang loading, terjadi error, daftar kosong, atau berhasil memuat data).
  Widget _buildBody(bool isDarkMode) {
    // 1. Loading State
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    // 2. Error State
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: _loadConversationHistory,
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Empty State
    if (_historyRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No conversation history',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    // 4. Data List State
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _historyRooms.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final conv = _historyRooms[index];
        return _buildHistoryItem(conv, isDarkMode);
      },
    );
  }

  Widget _buildHistoryItem(Conversation conv, bool isDarkMode) {
    final chatModel = conv.toChatModel();
    final contactName = conv.participantEmail;
    final lastMessage = conv.lastMessage.isNotEmpty ? conv.lastMessage : 'No messages';
    final timeFormatted = _formatTime(conv.lastMessageTime);
    final tags = conv.tags;
    final funnel = conv.funnel;
    final channelId = conv.chId;
    final channelName = conv.channelName;
    final botName = conv.agentName;
    final avatarUrl = conv.avatarUrl;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(
                chat: chatModel,
                isReadOnly: true,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Avatar ──
              CircleAvatar(
                radius: 22,
                backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Icon(
                        conv.isGroup ? Icons.group : Icons.person,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                        size: 22,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // ── Right: Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Name + Time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contactName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Row 2: Last Message
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Row 3: Tags & Funnel (conditional)
                    if (tags.isNotEmpty || funnel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Tags (max 2 + overflow)
                            ...tags.take(2).map((tag) => _buildTagChip(tag)),
                            if (tags.length > 2)
                              _buildOverflowChip('+${tags.length - 2}'),
                            // Funnel
                            if (funnel.isNotEmpty)
                              _buildFunnelChip(funnel),
                          ],
                        ),
                      ),

                    // Row 4: Channel + Channel Account Name + Status Status
                    Row(
                      children: [
                        ChannelIcon(chId: channelId, channelName: channelName, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getBotName(conv),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _getStatusChip(conv.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label, size: 12, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            tag,
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFunnelChip(String funnel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt, size: 12, color: Colors.purple.shade600),
          const SizedBox(width: 4),
          Text(
            funnel,
            style: TextStyle(fontSize: 11, color: Colors.purple.shade700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }



  String _getBotName(Conversation conv) {
    if (conv.agentName.isNotEmpty) {
      return conv.agentName;
    }
    
    if (conv.channelName.isNotEmpty && conv.channelName != 'Not Found') {
      return conv.channelName;
    }
    
    final chIdNum = int.tryParse(conv.chId) ?? 0;
    switch (chIdNum) {
      case 1:
      case 1557:
      case 1561:
        return 'Bot WA';
      case 2:
        return 'Telegram Bot';
      case 3:
        return 'Instagram Bot';
      case 4:
        return 'Messenger Bot';
      case 19:
        return 'Email Bot';
      default:
        return 'Bot';
    }
  }

  Widget _getStatusChip(String status) {
    String label = status;
    Color color;

    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'open' || status == '1') {
      label = 'Open';
      color = const Color(0xFF10B981);
    } else if (lowerStatus == 'pending' || status == '2') {
      label = 'Pending';
      color = const Color(0xFFF59E0B);
    } else if (lowerStatus == 'resolved' || status == '3') {
      label = 'Resolved';
      color = const Color(0xFF10B981);
    } else if (lowerStatus == 'archived' || status == '4') {
      label = 'Archived';
      color = const Color(0xFF6B7280);
    } else {
      label = status.isNotEmpty ? status : 'Open';
      color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
