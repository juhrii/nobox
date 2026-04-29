import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/model/message.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/providers/auth_provider.dart';

class ConversationHistoryPage extends StatefulWidget {
  final ChatModel chat;

  const ConversationHistoryPage({super.key, required this.chat});

  @override
  State<ConversationHistoryPage> createState() => _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  final ChatService _chatService = ChatService();
  List<Message> _messages = [];
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
  }

  void _loadInitialMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUser ?? '';
    
    setState(() {
      _isLoadingMessages = true;
    });

    final response = await _chatService.getMessageHistory(widget.chat.id, currentUserEmail);
    
    if (mounted) {
      setState(() {
        _isLoadingMessages = false;
        if (!response.isError && response.data != null) {
          _messages = response.data!;
        }
      });
    }
  }

  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawTime);
      final hr = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hr:$min';
    } catch (_) {
      return rawTime;
    }
  }

  Widget _buildChatBubble(Message message, bool isDark) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe
              ? (isDark ? Colors.blue.shade800 : const Color(0xFFDCF8C6))
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: message.isMe ? const Radius.circular(12) : const Radius.circular(0),
            bottomRight: message.isMe ? const Radius.circular(0) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.time),
                  style: TextStyle(
                    fontSize: 11,
                    color: (message.isMe && !isDark) ? Colors.black54 : (isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                ),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.status == MessageStatus.read ? Colors.blue : (isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF5F8FA),
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
              widget.chat.sender,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade500,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoadingMessages
            ? Center(child: CircularProgressIndicator(color: Colors.blue.shade300))
            : _messages.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
                    reverse: true, // Assuming newest messages are at the top of the list in response
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildChatBubble(message, isDark);
                    },
                  ),
      ),
    );
  }
}
