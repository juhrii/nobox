import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' hide Config;
import '../../../core/model/message.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/signalr_service.dart';
import '../../../core/model/message_request.dart';
import '../../../core/providers/chat_status_provider.dart';
import '../../../core/model/quick_reply_model.dart';

import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import 'contact_info_page.dart';
import 'starred_messages_page.dart';
import 'location_picker_page.dart';
import '../../widgets/add_agent_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../widgets/message_bubble_widget.dart';
import '../../widgets/voice_recording_bottom_sheet.dart';
import '../../widgets/message_shimmer_widget.dart';

class ChatDetailPage extends StatefulWidget {
  final ChatModel? chat;
  const ChatDetailPage({super.key, this.chat});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late ChatModel chat;
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  List<Message> _messages = [];
  bool _isLoadingMessages = true;
  Message? _repliedMessage;
  ChatStatusProvider? _statusProvider;
  StreamSubscription<Map<String, dynamic>>? _signalRSubscription;
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _showEmojiPicker = false;
  bool _showAttachmentPanel = false;
  final FocusNode _focusNode = FocusNode();

  // ── Message Selection State ──
  bool _isSelectionMode = false;
  final Set<int> _selectedMessageIndices = {};

  bool _isInit = false;
  String _archivedDateLabel = '';

  // ── Quick Reply State ──
  bool _isShowingQuickReply = false;
  List<QuickReplyTemplate> _quickReplyTemplates = [];
  bool _isLoadingQuickReply = false;
  Timer? _quickReplyDebounce;
  bool _isSettingQuickReply = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      if (widget.chat != null) {
        chat = widget.chat!;
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is ChatModel) {
          chat = args;
        } else {
          debugPrint('Warning: ChatDetailPage opened without valid ChatModel. Using dummy fallback.');
          chat = ChatModel(id: '', sender: 'Unknown', lastMessage: '', time: '');
        }
      }
      _isInit = true;

      if (chat.id.isNotEmpty) {
        // Set NotificationService to suppress push notifications while chatting
        NotificationService.activeChatId = chat.id;
        // Set PushNotificationService to suppress notifications while in this room
        PushNotificationService.setCurrentRoom(chat.id);
        // Hapus notifikasinya kalau masih ada menggantung
        NotificationService.clearNotification(chat.id);
        PushNotificationService.cancelNotificationsForRoom(chat.id);
      }
    }
  }



  // Voice message state
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  // New state for recording bottom sheet
  String? _recordedVoicePath;
  int? _recordedVoiceDuration;

  @override
  void dispose() {
    // Reset notification suppression when leaving chat
    if (_isInit) {
      NotificationService.activeChatId = null;
      PushNotificationService.setCurrentRoom(null);
      final provider = _statusProvider;
      final sender = chat.sender;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider?.setLastSeen(sender);
      });
    }
    _signalRSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    _quickReplyDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _messageController.addListener(() {
      if (_isSettingQuickReply) return; // Skip if we are injecting a template
      
      final text = _messageController.text;
      final composing = text.trim().isNotEmpty;
      if (composing != _isComposing) {
        setState(() => _isComposing = composing);
      }

      // Quick Reply Detection
      if (text.startsWith('/')) {
        final searchText = text.substring(1);
        if (!_isShowingQuickReply) {
          setState(() => _isShowingQuickReply = true);
        }
        
        // Debounce API call
        if (_quickReplyDebounce?.isActive ?? false) _quickReplyDebounce!.cancel();
        _quickReplyDebounce = Timer(const Duration(milliseconds: 300), () {
          _fetchQuickReplies(searchText);
        });
      } else {
        if (_isShowingQuickReply) {
          setState(() => _isShowingQuickReply = false);
        }
      }
    });

    // Listen to audio player state changes
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playbackDuration = dur);
    });
  }

  Future<void> _fetchQuickReplies(String searchText) async {
    setState(() => _isLoadingQuickReply = true);
    final response = await _chatService.getQuickReplyTemplates(containsText: searchText);
    if (mounted) {
      setState(() {
        _isLoadingQuickReply = false;
        if (!response.isError && response.data != null) {
          _quickReplyTemplates = response.data!;
        } else {
          _quickReplyTemplates = [];
        }
      });
    }
  }

  Widget _buildQuickReplyList(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quick Reply Templates',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_isLoadingQuickReply)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  )
                else
                  Text(
                    '${_quickReplyTemplates.length} templates',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List Items
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _quickReplyTemplates.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final template = _quickReplyTemplates[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final newText = template.content;
                    
                    _isSettingQuickReply = true; // flag ON

                    setState(() {
                      _isShowingQuickReply = false; // tutup popup dulu
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _focusNode.requestFocus();
                      _messageController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(offset: newText.length),
                      );
                      _isSettingQuickReply = false; // flag OFF
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            template.command,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          template.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade300 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _debugApiState = '';

  void _loadInitialMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUser ?? '';
    
    setState(() {
      _isLoadingMessages = true;
      _debugApiState = 'Memanggil API untuk RoomId: ${chat.id}...';
    });

    if (chat.isArchived) {
      // ── ARCHIVED: gunakan endpoint DetailArchived (seperti mentor) ──
      debugPrint('ChatDetail: Chat is archived, using getArchivedRoomDetail');
      
      final archivedResponse = await _chatService.getArchivedRoomDetail(chat.id);
      
      debugPrint('ChatDetail: Archived response - Error? ${archivedResponse.isError}');
      
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isLoadingMessages = false;
            
            if (archivedResponse.isError) {
              _debugApiState = 'API Error: ${archivedResponse.error}';
              return;
            }
            
            final data = archivedResponse.data;
            if (data == null) {
              _debugApiState = 'API mengembalikan data null.';
              return;
            }
            
            // Debug: log tipe & nilai dari key Messages
            debugPrint('ChatDetail: data["Messages"] runtimeType=${data['Messages']?.runtimeType}');
            
            // Struktur dari DetailArchived:
            // Data.Messages = Map { Id, RoomId, St, Msgs: [...] }
            // Pesan sebenarnya ada di Data.Messages.Msgs
            List<dynamic> messagesList = [];
            
            final messagesObj = data['Messages'];
            if (messagesObj is Map && messagesObj['Msgs'] != null) {
              final msgs = messagesObj['Msgs'];
              if (msgs is List) {
                messagesList = msgs;
                debugPrint('ChatDetail: ✅ Found ${messagesList.length} messages at Data.Messages.Msgs (List)');
              } else if (msgs is String) {
                // Msgs mungkin berupa JSON string
                try {
                  final decoded = jsonDecode(msgs);
                  if (decoded is List) {
                    messagesList = decoded;
                    debugPrint('ChatDetail: ✅ Found ${messagesList.length} messages at Data.Messages.Msgs (decoded JSON string)');
                  }
                } catch (e) {
                  debugPrint('ChatDetail: ❌ Failed to decode Msgs string: $e');
                }
              }
            } else if (messagesObj is List) {
              messagesList = messagesObj;
              debugPrint('ChatDetail: ✅ Found ${messagesList.length} messages at Data.Messages (List)');
            }
            
            if (messagesList.isEmpty) {
              final keysInfo = data.entries.map((e) => '${e.key}(${e.value?.runtimeType})').join(', ');
              debugPrint('ChatDetail: ⚠️ No messages found. Detail: $keysInfo');
              _debugApiState = 'Msgs kosong. Data.Messages type=${messagesObj?.runtimeType}';
              return;
            }
            
            if (messagesList.isEmpty) {
              _debugApiState = 'API berhasil tapi 0 pesan (kosong) dari server.';
              return;
            }
            
            // Ambil tanggal arsip dari Room data
            if (data['Room'] is Map) {
              final room = data['Room'] as Map;
              final timeArchived = room['TimeArchived']?.toString() ?? '';
              final roomIn = room['In']?.toString() ?? '';
              // TimeArchived dari API bisa berupa angka hari atau timestamp
              if (timeArchived.isNotEmpty && timeArchived != 'null') {
                // Coba parse sebagai datetime dulu
                final dt = DateTime.tryParse(timeArchived);
                if (dt != null) {
                  _archivedDateLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                } else {
                  // Jika numerik (hari), hitung dari room.In
                  final days = int.tryParse(timeArchived);
                  final baseDate = DateTime.tryParse(roomIn);
                  if (days != null && baseDate != null) {
                    final archivedDate = baseDate.add(Duration(days: days));
                    _archivedDateLabel = '${archivedDate.day.toString().padLeft(2, '0')}/${archivedDate.month.toString().padLeft(2, '0')}/${archivedDate.year} ${archivedDate.hour.toString().padLeft(2, '0')}:${archivedDate.minute.toString().padLeft(2, '0')}';
                  } else {
                    _archivedDateLabel = timeArchived;
                  }
                }
              }
            }

            // Parse ke List<Message>
            try {
              _messages = messagesList.map((json) {
                return Message.fromJson(json, currentUserEmail, tenantId: _chatService.currentTenantId);
              }).toList();
              _debugApiState = 'Berhasil mengambil ${_messages.length} pesan dari arsip.';
              debugPrint('ChatDetail: ✅ Parsed ${_messages.length} archived messages');
            } catch (e) {
              debugPrint('ChatDetail: ❌ Error parsing archived messages: $e');
              _debugApiState = 'Error parsing pesan: $e';
            }
          });
        });
      }
    } else {
      // ── NORMAL: gunakan getMessageHistory seperti biasa ──
      debugPrint('ChatDetail: Chat is active, using getMessageHistory');
      
      final response = await _chatService.getMessageHistory(chat.id, currentUserEmail);
      
      debugPrint('ChatDetail API Response for ${chat.id}: Error? ${response.isError}, Data Length: ${response.data?.length}');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isLoadingMessages = false;
            if (response.isError) {
              _debugApiState = 'API Error: ${response.error}';
            } else if (response.data == null || response.data!.isEmpty) {
              _debugApiState = 'API berhasil dipanggil tapi mengembalikan 0 pesan (Kosong) dari server.';
            } else {
              _debugApiState = 'Berhasil mengambil ${response.data!.length} pesan.';
              _messages = response.data!;
            }
          });
        });
      }
    }
  }

  /// Subscribe to SignalR for real-time incoming messages
  void _subscribeToSignalR() {
    final signalR = SignalRService();

    // Listen to TerimaPesan (pre-parsed by SignalRService)
    _signalRSubscription = signalR.onTerimaPesan.listen((data) {
      final incomingRoomId = data['roomId']?.toString() ?? '';
      final messageData = data['message'] as Map<String, dynamic>? ?? {};
      final senderData = data['sender'] as Map<String, dynamic>?;

      debugPrint('ChatDetailPage: TerimaPesan | room=$incomingRoomId | current=${chat.id}');

      // ❗ FILTER: Only process messages for THIS room
      if (incomingRoomId.isEmpty || incomingRoomId != chat.id) {
        debugPrint('SignalR: 🛑 Pesan DIABAIKAN. (Beda Room). Incoming: $incomingRoomId | Current: ${chat.id}');
        return;
      }

      // Skip our own outgoing messages (AgentId present = sent by agent/us)
      final agentId = messageData['AgentId'];
      if (agentId != null && agentId != 0 && agentId.toString() != '0') {
        debugPrint('SignalR: Skipping own outgoing message in room $incomingRoomId');
        return;
      }

      // Extract content from NoBox payload
      final content = messageData['Msg']?.toString() ?? '';
      final timeStr = messageData['In']?.toString() ?? DateTime.now().toIso8601String();

      if (mounted && content.isNotEmpty) {
        final msgTime = DateTime.tryParse(timeStr) ?? DateTime.now();
        setState(() {
          _messages.add(Message(
            content: content,
            isMe: false,
            time: _formatFullTime(msgTime),
            status: MessageStatus.read,
          ));
        });
        _scrollToBottom();

        // Tell server we've read this message
        try {
          final roomIdInt = int.tryParse(chat.id);
          if (roomIdInt != null) {
            signalR.sendReadCount(roomIdInt);
          }
        } catch (_) {}
      }
    });
  }

  /// Format time as "DD Mon, HH:mm" (e.g., "06 Jan, 12:29")
  String _formatFullTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        // With reverse: true, position 0.0 is the newest message (bottom)
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _initializeChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.chat != null) {
        chat = widget.chat!;
      } else {
        chat = ModalRoute.of(context)!.settings.arguments as ChatModel;
      }
      _statusProvider = Provider.of<ChatStatusProvider>(context, listen: false);
      _loadInitialMessages();
      _subscribeToSignalR();
    });
  }

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to delete all messages in this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared')),
              );
            },
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBackgroundPicker() {
    final settings = Provider.of<ChatSettingsProvider>(context, listen: false);
    final colors = [
      null,
      Colors.blueGrey[50],
      Colors.green[50],
      Colors.purple[50],
      Colors.amber[50],
      Colors.red[50],
      Colors.blue[50],
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Solid colors row
            const Text('Solid Colors', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final color = colors[index];
                  final isSelected = settings.backgroundImagePath == null && settings.backgroundColor == color;

                  return GestureDetector(
                    onTap: () {
                      settings.setBackgroundColor(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: color ?? Colors.grey[200],
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                      ),
                      child: color == null ? const Icon(Icons.block, size: 20) : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Wallpaper image option
            const Text('Wallpaper', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final XFile? picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1920,
                      maxHeight: 1920,
                      imageQuality: 90,
                    );
                    if (picked != null) {
                      settings.setBackgroundImage(picked.path);
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: settings.backgroundImagePath != null
                          ? Border.all(color: Colors.blue, width: 3)
                          : null,
                    ),
                    child: const Icon(Icons.image, color: Colors.blue, size: 24),
                  ),
                ),
                if (settings.backgroundImagePath != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(settings.backgroundImagePath!),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Current', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final now = DateTime.now();
    final timeString = _formatFullTime(now);
    
    final newMessage = Message(
      content: content,
      isMe: true,
      time: timeString,
      status: MessageStatus.sent,
      repliedMessage: _repliedMessage,
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
      _repliedMessage = null;
    });

    _scrollToBottom();

    final messageIndex = _messages.indexOf(newMessage);

    // Use contactId for Inbox/Send endpoint
    final inboxId = chat.id; // Use RoomId for Inbox/Send
    final response = await _chatService.sendMessage(
      MessageRequest(
        receiver: chat.id,
        content: content,
        accountId: chat.accountId,
        channelId: chat.chId,
        contactId: chat.contactId,
      ),
    );

    if (mounted && messageIndex < _messages.length) {
      if (!response.isError) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.delivered,
          );
        });

        Timer(const Duration(seconds: 2), () {
          if (mounted && messageIndex < _messages.length) {
            setState(() {
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                status: MessageStatus.read,
              );
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${response.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  ATTACHMENT PANEL TOGGLE
  // ─────────────────────────────────────────────

  void _toggleAttachmentPanel() {
    setState(() {
      _showAttachmentPanel = !_showAttachmentPanel;
      if (_showAttachmentPanel) {
        _showEmojiPicker = false;
      }
    });
  }

  // ─────────────────────────────────────────────
  //  PICK & SEND IMAGE FROM CAMERA
  // ─────────────────────────────────────────────

  Future<void> _pickAndSendFromCamera() async {
    setState(() => _showAttachmentPanel = false);
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null) return;
    _sendPickedImage(pickedFile);
  }

  // ─────────────────────────────────────────────
  //  PICK & SEND VIDEO
  // ─────────────────────────────────────────────

  Future<void> _pickAndSendVideo() async {
    setState(() => _showAttachmentPanel = false);
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (pickedFile == null) return;

    final now = DateTime.now();
    final timeString = _formatFullTime(now);

    final newMessage = Message(
      content: '🎬 Video',
      isMe: true,
      time: timeString,
      status: MessageStatus.sent,
      messageType: MessageType.image,
      imagePath: pickedFile.path,
    );

    setState(() {
      _messages.add(newMessage);
    });

    _scrollToBottom();

    final messageIndex = _messages.indexOf(newMessage);

    final response = await _chatService.sendImageMessage(
      chat.id,
      pickedFile.path,
      accountId: chat.accountId,
      channelId: chat.chId,
      contactId: chat.contactId,
    );

    if (mounted && messageIndex < _messages.length) {
      if (!response.isError) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.delivered,
            imageUrl: response.data,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send video: ${response.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  SEND PICKED IMAGE HELPER
  // ─────────────────────────────────────────────

  Future<void> _sendPickedImage(XFile pickedFile) async {
    final now = DateTime.now();
    final timeString = _formatFullTime(now);

    final newMessage = Message(
      content: '📷 Photo',
      isMe: true,
      time: timeString,
      status: MessageStatus.sent,
      messageType: MessageType.image,
      imagePath: pickedFile.path,
    );

    setState(() {
      _messages.add(newMessage);
    });

    _scrollToBottom();

    final messageIndex = _messages.indexOf(newMessage);

    final response = await _chatService.sendImageMessage(
      chat.id,
      pickedFile.path,
      accountId: chat.accountId,
      channelId: chat.chId,
      contactId: chat.contactId,
    );

    if (mounted && messageIndex < _messages.length) {
      if (!response.isError) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.delivered,
            imageUrl: response.data,
          );
        });

        Timer(const Duration(seconds: 2), () {
          if (mounted && messageIndex < _messages.length) {
            setState(() {
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                status: MessageStatus.read,
              );
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: ${response.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  PICK & SEND DOCUMENT
  // ─────────────────────────────────────────────

  Future<void> _pickAndSendDocument() async {
    setState(() => _showAttachmentPanel = false);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      final now = DateTime.now();
      final timeString = _formatFullTime(now);

      final newMessage = Message(
        content: '📄 ${file.name}',
        isMe: true,
        time: timeString,
        status: MessageStatus.sent,
      );

      setState(() {
        _messages.add(newMessage);
      });

      _scrollToBottom();

      final messageIndex = _messages.indexOf(newMessage);

      final response = await _chatService.sendImageMessage(
        chat.id,
        file.path!,
        accountId: chat.accountId,
        channelId: chat.chId,
        contactId: chat.contactId,
      );

      if (mounted && messageIndex < _messages.length) {
        if (!response.isError) {
          setState(() {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.delivered,
            );
          });

          Timer(const Duration(seconds: 2), () {
            if (mounted && messageIndex < _messages.length) {
              setState(() {
                _messages[messageIndex] = _messages[messageIndex].copyWith(
                  status: MessageStatus.read,
                );
              });
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal kirim dokumen: ${response.error}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().length > 60 ? '${e.toString().substring(0, 60)}...' : e}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  SHARE LOCATION
  // ─────────────────────────────────────────────

  Future<void> _shareLocation() async {
    setState(() => _showAttachmentPanel = false);

    // Navigate to map picker
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(),
      ),
    );

    if (pickedLocation == null || !mounted) return;

    final lat = pickedLocation.latitude;
    final lng = pickedLocation.longitude;
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';

    final now = DateTime.now();
    final timeString = _formatFullTime(now);

    final newMessage = Message(
      content: '📍 Lokasi saya\n$mapsUrl',
      isMe: true,
      time: timeString,
      status: MessageStatus.sent,
    );

    setState(() {
      _messages.add(newMessage);
    });

    _scrollToBottom();

    final messageIndex = _messages.indexOf(newMessage);

    final response = await _chatService.sendMessage(
      MessageRequest(
        receiver: chat.id,
        content: '📍 Lokasi saya\n$mapsUrl',
        accountId: chat.accountId,
        channelId: chat.chId,
        contactId: chat.contactId,
      ),
    );

    if (mounted && messageIndex < _messages.length) {
      if (!response.isError) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.delivered,
          );
        });

        Timer(const Duration(seconds: 2), () {
          if (mounted && messageIndex < _messages.length) {
            setState(() {
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                status: MessageStatus.read,
              );
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal kirim lokasi: ${response.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  PICK & SEND IMAGE FROM GALLERY
  // ─────────────────────────────────────────────

  Future<void> _pickAndSendImage() async {
    setState(() => _showAttachmentPanel = false);
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final now = DateTime.now();
    final timeString = _formatFullTime(now);

    final newMessage = Message(
      content: '📷 Photo',
      isMe: true,
      time: timeString,
      status: MessageStatus.sent,
      messageType: MessageType.image,
      imagePath: pickedFile.path,
    );

    setState(() {
      _messages.add(newMessage);
    });

    _scrollToBottom();

    final messageIndex = _messages.indexOf(newMessage);

    final response = await _chatService.sendImageMessage(
      chat.id,
      pickedFile.path,
      accountId: chat.accountId,
      channelId: chat.chId,
      contactId: chat.contactId,
    );

    if (mounted && messageIndex < _messages.length) {
      if (!response.isError) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.delivered,
            imageUrl: response.data,
          );
        });

        Timer(const Duration(seconds: 2), () {
          if (mounted && messageIndex < _messages.length) {
            setState(() {
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                status: MessageStatus.read,
              );
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: ${response.error}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  VOICE RECORDING
  // ─────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        debugPrint('Recording: Starting recording to $path');

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        debugPrint('Recording: Started successfully');

        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && !_isRecordingPaused) {
            setState(() => _recordingSeconds++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin mikrofon diperlukan untuk merekam suara'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      setState(() => _isRecordingPaused = true);
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() => _isRecordingPaused = false);
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  Future<String?> _finalizeRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _isRecordingPaused = false;
          _recordedVoicePath = path;
          _recordedVoiceDuration = _recordingSeconds;
        });
      }
      return path;
    } catch (e) {
      debugPrint('Error finalizing recording: $e');
      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
      });
      return null;
    }
  }

  Future<void> _sendVoiceNote(String path, int duration) async {
    try {
      final now = DateTime.now();
      final timeString = _formatFullTime(now);

      // Add voice message to chat immediately (with 'sent' status = uploading)
      final voiceMessage = Message(
        content: '🎤 Voice message',
        isMe: true,
        time: timeString,
        status: MessageStatus.sent,
        messageType: MessageType.voice,
        audioPath: path,
        audioDuration: duration,
      );

      setState(() {
        _messages.add(voiceMessage);
      });
      _scrollToBottom();

      final messageIndex = _messages.indexOf(voiceMessage);

      final response = await _chatService.sendImageMessage(
        chat.id,
        path,
        accountId: chat.accountId,
        channelId: chat.chId,
        contactId: chat.contactId,
      );

      if (mounted && messageIndex < _messages.length) {
       // ✅ FIX
if (!response.isError) {
  setState(() {
    _messages[messageIndex] = _messages[messageIndex].copyWith(
      status: MessageStatus.delivered,
      audioPath: response.data, // URL dari server
    );
  });
          Timer(const Duration(seconds: 2), () {
            if (mounted && messageIndex < _messages.length) {
              setState(() {
                _messages[messageIndex] = _messages[messageIndex].copyWith(
                  status: MessageStatus.read,
                );
              });
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal kirim voice: ${response.error}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending voice note: $e');
    }
  }

  Future<void> _stopRecording() async {
    final path = await _finalizeRecording();
    if (path != null) {
      await _sendVoiceNote(path, _recordedVoiceDuration ?? 0);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      if (mounted) setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
      });
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
      if (mounted) setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
      });
    }
  }

  void _showVoiceBottomSheet() async {
    // Start recording first
    await _startRecording();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => VoiceRecordingBottomSheet(
        initialSeconds: _recordingSeconds,
        isRecording: _isRecording,
        isPaused: _isRecordingPaused,
        onPause: _pauseRecording,
        onResume: _resumeRecording,
        onStop: _finalizeRecording,
        onDelete: _cancelRecording,
        onReRecord: _startRecording,
        onSend: _sendVoiceNote,
        audioPlayer: _audioPlayer,
      ),
    );
  }

  Future<void> _togglePlayback(String path) async {
    try {
      final isUrl = path.startsWith('http');

      if (!isUrl) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('Playback: FILE NOT FOUND: $path');
          return;
        }
      }

      if (_isPlaying && _currentlyPlayingPath == path) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.stop();
        setState(() {
          _playbackPosition = Duration.zero;
          _playbackDuration = Duration.zero;
        });

        if (isUrl) {
          await _audioPlayer.play(UrlSource(path));
        } else {
          await _audioPlayer.play(DeviceFileSource(path));
        }

        setState(() {
          _isPlaying = true;
          _currentlyPlayingPath = path;
        });
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showEmojiPicker = true);
      });
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursorPos = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final newText = text.substring(0, cursorPos) + emoji.emoji + text.substring(cursorPos);
    final newCursorPos = cursorPos + emoji.emoji.length;
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(offset: newCursorPos);
  }



  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.chat != null) {
      chat = widget.chat!;
    } else {
      chat = ModalRoute.of(context)!.settings.arguments as ChatModel;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar(isDark) : _buildAppBar(isDark),
      body: Consumer<ChatSettingsProvider>(
        builder: (context, settings, _) {
          return Container(
          decoration: BoxDecoration(
            color: settings.backgroundImagePath == null
                ? (settings.backgroundColor ?? (isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5)))
                : null,
            image: settings.backgroundImagePath != null
                ? DecorationImage(
                    image: FileImage(File(settings.backgroundImagePath!)),
                    fit: BoxFit.cover,
                    colorFilter: isDark
                        ? ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)
                        : null,
                  )
                : null,
          ),
            child: Column(
              children: [
                Expanded(child: _buildMessageList(isDark)),
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!chat.isArchived) ...[
                        if (_isShowingQuickReply && _quickReplyTemplates.isNotEmpty) _buildQuickReplyList(isDark),
                        if (_repliedMessage != null) _buildReplyPreview(isDark),
                        _buildInputBar(isDark),
                        if (_showAttachmentPanel) _buildAttachmentPanel(isDark),
                        if (_showEmojiPicker) _buildEmojiPicker(isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchivedBanner(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1F2C34) : Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 20, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'This conversation has been archived.',
              style: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  RESTORE ARCHIVED DIALOG
  // ─────────────────────────────────────────────

  void _showRestoreArchivedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Unarchive Conversation',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Are you sure you want to unarchive this conversation?',
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
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              await chatProvider.toggleArchive(chat.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Conversation unarchived successfully'),
                    backgroundColor: Colors.blue.shade700,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  ARCHIVE CONVERSATION (from popup menu)
  // ─────────────────────────────────────────────

  void _handleArchiveConversation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Archive Conversation',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
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

              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => WillPopScope(
                  onWillPop: () async => false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dialogBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(color: Colors.blue),
                          SizedBox(height: 16),
                          Text(
                            'Archiving conversation...',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              await chatProvider.toggleArchive(chat.id);

              if (mounted) {
                Navigator.pop(context); // close loading overlay
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Conversation archived successfully'),
                      ],
                    ),
                    backgroundColor: Colors.blue.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
                Navigator.pop(context); // go back to chat list
              }
            },
            child: const Text('Confirm', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  APP BAR — matching screenshot
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark) {
    // ── ARCHIVED APP BAR ──
    if (chat.isArchived) {
      return AppBar(
        backgroundColor: Colors.blue,
        surfaceTintColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        leadingWidth: 30,
        titleSpacing: 12,
        title: const Text(
          'This conversation has been archived.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Sidebar (Contact Info)
          IconButton(
            icon: CustomPaint(
              size: const Size(26, 22),
              painter: _SidebarIconPainter(color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactInfoPage(chat: chat),
                ),
              );
            },
          ),
          // Restore (styled as delete icon)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Restore Chat',
            onPressed: () => _showRestoreArchivedDialog(),
          ),
        ],
      );
    }

    // ── NORMAL APP BAR (non-archived) ──
    return AppBar(
      backgroundColor: Colors.blue,
      surfaceTintColor: Colors.blue,
      iconTheme: const IconThemeData(color: Colors.white),
      leadingWidth: 30,
      titleSpacing: 8,
      title: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactInfoPage(chat: chat),
            ),
          );
        },
        child: Row(
        children: [
          // Avatar
          Hero(
            tag: 'avatar_${chat.id}',
            child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade300,
            backgroundImage: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                ? NetworkImage(chat.avatarUrl!)
                : null,
            child: chat.avatarUrl == null || chat.avatarUrl!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 22)
                : null,
          ),
          ),
          const SizedBox(width: 10),
          // Name & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.sender,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<ChatStatusProvider>(
                  builder: (context, statusProvider, _) {                    // Show WhatsApp icon + account name (channelName)
                    if (chat.channelName.isNotEmpty && chat.channelName != 'Not Found') {
                      return Row(
                        children: [
                          FaIcon(FontAwesomeIcons.whatsapp, size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              chat.channelName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      actions: [
        IconButton(
          icon: CustomPaint(
            size: const Size(26, 22),
            painter: _SidebarIconPainter(color: Colors.white),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContactInfoPage(chat: chat),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) {
            if (value == 'add_agent') {
              _showAddAgentDialog();
            } else if (value == 'mark_resolved') {
              _showResolveConfirmation();
            } else if (value == 'archive_conversation') {
              _handleArchiveConversation();
            } else if (value == 'help') {
              _openHelpUrl();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'add_agent',
              child: Row(
                children: [
                  Icon(Icons.person_add_alt, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 16),
                  const Text('Add Human Agent', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'mark_resolved',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 16),
                  const Text('Mark as Resolved', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'archive_conversation',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 16),
                  const Text('Archived Conversation', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 24, color: Colors.red),
                  SizedBox(width: 16),
                  Text('Help', style: TextStyle(color: Colors.red, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  SELECTION APP BAR — matching WhatsApp style
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildSelectionAppBar(bool isDark) {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2), // Biru tua standar seperti di gambar referensi
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          setState(() {
            _isSelectionMode = false;
            _selectedMessageIndices.clear();
          });
        },
      ),
      title: Text(
        '${_selectedMessageIndices.length} selected',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        // Reply
        IconButton(
          icon: const Icon(Icons.reply, color: Colors.white),
          onPressed: () {
            if (_selectedMessageIndices.length == 1) {
              final msgIndex = _selectedMessageIndices.first;
              if (msgIndex >= 0 && msgIndex < _messages.length) {
                setState(() {
                  _repliedMessage = _messages[msgIndex];
                  _isSelectionMode = false;
                  _selectedMessageIndices.clear();
                });
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pilih 1 pesan saja untuk reply')),
              );
            }
          },
        ),
        // Forward
        IconButton(
          icon: const Icon(Icons.forward, color: Colors.white),
          onPressed: () {
            _showForwardSelectedDialog();
          },
        ),
        // Copy / Salin
        IconButton(
          icon: const Icon(Icons.copy, color: Colors.white),
          onPressed: () {
            final buffer = StringBuffer();
            final sortedIndices = _selectedMessageIndices.toList()..sort();
            for (final idx in sortedIndices) {
              if (idx >= 0 && idx < _messages.length) {
                buffer.writeln(_messages[idx].content);
              }
            }
            Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
            setState(() {
              _isSelectionMode = false;
              _selectedMessageIndices.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pesan tersalin')),
            );
          },
        ),

        // Delete / Trash
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Hapus Pesan'),
                content: Text('Hapus ${_selectedMessageIndices.length} pesan yang dipilih untuk semua orang?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Menghapus pesan...')),
                      );
                      
                      final sortedIndices = _selectedMessageIndices.toList()..sort((a, b) => b.compareTo(a));
                      bool hasError = false;
                      
                      for (final idx in sortedIndices) {
                        if (idx >= 0 && idx < _messages.length) {
                           final msgId = _messages[idx].id; 
                           if (msgId.isNotEmpty) {
                             // Panggil API penghapusan
                             final resp = await _chatService.deleteMessage(msgId);
                             if (resp.isError) {
                               hasError = true;
                             } else {
                               setState(() {
                                 _messages.removeAt(idx);
                               });
                             }
                           } else {
                             // Jika pesan lokal / tidak ada ID
                             setState(() {
                               _messages.removeAt(idx);
                             });
                           }
                        }
                      }
                      
                      setState(() {
                        _isSelectionMode = false;
                        _selectedMessageIndices.clear();
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(hasError ? 'Beberapa pesan gagal dihapus, pastikan endpoint Nobox tersedia.' : 'Pesan berhasil dihapus dari server.')),
                      );
                    },
                    child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  ADD HUMAN AGENT DIALOG
  // ─────────────────────────────────────────────

  void _showAddAgentDialog() {
    showDialog(
      context: context,
      builder: (_) => AddAgentDialog(
        chatId: chat.id,
        contactId: chat.contactId,
        chId: chat.chId,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  MARK AS RESOLVED
  // ─────────────────────────────────────────────

  void _showResolveConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Mark as Resolved',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black),
          ),
          content: const Text(
            'Are you sure you want to mark this conversation as resolved? You won\'t be able to send messages after this.',
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel', 
                style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 15)
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                _markAsResolved(); // Execute the actual function
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Emerald/Green color
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Mark as Resolved', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void _markAsResolved() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      final response = await _chatService.resolveConversation(chat.id);
      if (mounted) {
        if (!response.isError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation marked as resolved')),
          );
          chatProvider.fetchChats();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${response.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  HELP ACTION
  // ─────────────────────────────────────────────

  void _openHelpUrl() async {
    final Uri url = Uri.parse('https://ubig-co-1.gitbook.io/nobox-ai/real-base-ai-articles-english/menu/messages/inbox');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open help center page')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  MESSAGE LIST
  // ─────────────────────────────────────────────

  Widget _buildMessageList(bool isDark) {
    if (_isLoadingMessages) {
      return const MessageShimmerWidget();
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Belum ada pesan di sini.\nKetik sesuatu untuk memulai!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _debugApiState,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // +1 for "No more messages" header at top, +1 for archived footer at bottom
    final hasArchivedFooter = chat.isArchived;
    final extraItems = 1 + (hasArchivedFooter ? 1 : 0);
    final totalItems = _messages.length + extraItems;

    // Align.topCenter + shrinkWrap ensures messages start from top when few,
    // while reverse: true keeps newest messages at bottom and auto-scroll works.
    return Align(
      alignment: Alignment.topCenter,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: totalItems,
        itemBuilder: (context, index) {
        // With reverse: true, index 0 = bottom-most item
        
        // Index 0: Archived footer (if applicable)
        if (hasArchivedFooter && index == 0) {
          return _buildArchivedDivider();
        }

        // Adjust index for archived footer offset
        final adjustedIndex = hasArchivedFooter ? index - 1 : index;

        // Last index (top of screen): "No more messages" header
        if (adjustedIndex == _messages.length) {
          return _buildNoMoreMessages();
        }

        // Map reversed index to message index (newest = index 0, oldest = last)
        // Messages are stored oldest-first, so reverse the access
        final messageIndex = _messages.length - 1 - adjustedIndex;
        final message = _messages[messageIndex];
        // The message visually above this one (older) for date separator check
        final prevMessage = (messageIndex > 0) ? _messages[messageIndex - 1] : null;

        // System message
        if (message.isSystemMessage) {
          return _buildSystemMessage(message, isDark);
        }

        // Date separator — show when this message has a different date from the one above it
        Widget? dateSeparator;
        if (prevMessage == null || _shouldShowDateSeparator(prevMessage, message)) {
          dateSeparator = _buildDateSeparator(message.time, isDark);
        }

        // Normal chat bubble with swipe-to-reply + long-press selection
        final isSelected = _selectedMessageIndices.contains(messageIndex);

        if (message.messageType == MessageType.video) {
          return Column(
            children: [
              if (dateSeparator != null) dateSeparator,
              _buildVideoBubble(message, isDark),
            ],
          );
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
              MessageBubbleWidget(
                message: message,
                allMessages: _messages,
                isSelected: isSelected,
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedMessageIndices.add(messageIndex);
                  });
                },
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (_selectedMessageIndices.contains(messageIndex)) {
                        _selectedMessageIndices.remove(messageIndex);
                        if (_selectedMessageIndices.isEmpty) {
                          _isSelectionMode = false;
                        }
                      } else {
                        _selectedMessageIndices.add(messageIndex);
                      }
                    });
                  }
                },
                onReply: () {
                  setState(() => _repliedMessage = message);
                },
                onForward: () {
                  _showForwardDialog(message);
                },
                onCopy: () {
                   Clipboard.setData(ClipboardData(text: message.content));
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Pesan disalin')),
                   );
                },
              ),
          ],
        );
        },
      ),
    );
  }

  /// Archived divider widget — shown once at the bottom of archived chat messages
  Widget _buildArchivedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade400, thickness: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      'Agent archived this conversation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _archivedDateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade400, thickness: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBubble(Message message, bool isDark) {
    final isMe = message.isMe;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.blue
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe
                ? const Radius.circular(12)
                : const Radius.circular(2),
            bottomRight: isMe
                ? const Radius.circular(2)
                : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Video player widget
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: message.videoUrl != null
                  ? _VideoPlayerWidget(videoUrl: message.videoUrl!)
                  : Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.videocam_off,
                            color: Colors.white54, size: 40),
                      ),
                    ),
            ),
            // Timestamp
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.time,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white70
                          : (isDark
                              ? Colors.grey[500]
                              : Colors.grey[600]),
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _getStatusIcon(message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// Check if we should show a date separator between two messages
  bool _shouldShowDateSeparator(Message prev, Message current) {
    final prevDate = _extractDate(prev.time);
    final curDate = _extractDate(current.time);
    if (prevDate == null || curDate == null) return false;
    return prevDate.day != curDate.day || prevDate.month != curDate.month || prevDate.year != curDate.year;
  }

  DateTime? _extractDate(String timeStr) {
    // Format "DD Mon, HH:mm" e.g. "06 Jan, 12:29"
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    try {
      final parts = timeStr.split(', ');
      if (parts.length < 2) return null;
      final dayMonth = parts[0].split(' ');
      if (dayMonth.length < 2) return null;
      final day = int.parse(dayMonth[0]);
      final monthIdx = months.indexOf(dayMonth[1]) + 1;
      if (monthIdx == 0) return null;
      return DateTime(DateTime.now().year, monthIdx, day);
    } catch (_) {
      return null;
    }
  }

  Widget _buildDateSeparator(String timeStr, bool isDark) {
    final date = _extractDate(timeStr);
    String label;
    if (date != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(date.year, date.month, date.day);
      final diff = today.difference(msgDay).inDays;
      if (diff == 0) {
        label = 'Hari Ini';
      } else if (diff == 1) {
        label = 'Kemarin';
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        label = '${date.day} ${months[date.month - 1]} ${date.year}';
      }
    } else {
      label = timeStr;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800.withOpacity(0.7) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  /// Swipe-to-reply gesture wrapper
  Widget _buildSwipeToReply({required Message message, required Widget child}) {
    double dragOffset = 0;
    bool triggered = false;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setLocalState(() {
              dragOffset = (dragOffset + details.delta.dx).clamp(0.0, 80.0);
              if (dragOffset >= 60 && !triggered) {
                triggered = true;
              }
            });
          },
          onHorizontalDragEnd: (details) {
            if (triggered) {
              setState(() => _repliedMessage = message);
            }
            setLocalState(() {
              dragOffset = 0;
              triggered = false;
            });
          },
          onHorizontalDragCancel: () {
            setLocalState(() {
              dragOffset = 0;
              triggered = false;
            });
          },
          child: Stack(
            children: [
              // Reply icon behind
              if (dragOffset > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: AnimatedOpacity(
                        opacity: (dragOffset / 60).clamp(0.0, 1.0),
                        duration: const Duration(milliseconds: 50),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: triggered ? Colors.blue : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.reply, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              // Chat bubble
              AnimatedContainer(
                duration: Duration(milliseconds: dragOffset == 0 ? 200 : 0),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(dragOffset, 0, 0),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet with message options (Reply, Star)
  void _showMessageOptions(Message message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final msgId = '${message.content.hashCode}_${message.time}';
    final starred = chatProvider.isStarred(msgId);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.blue),
              title: const Text('Balas'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _repliedMessage = message);
              },
            ),
            ListTile(
              leading: Icon(
                starred ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              title: Text(starred ? 'Hapus Bintang' : 'Tandai Bintang'),
              onTap: () {
                Navigator.pop(ctx);
                chatProvider.toggleStar(
                  msgId,
                  content: message.content,
                  sender: message.isMe ? 'Saya' : chat.sender,
                  time: message.time,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(starred ? 'Bintang dihapus' : 'Pesan ditandai ⭐'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.teal),
              title: const Text('Salin'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesan disalin'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward, color: Colors.deepPurple),
              title: const Text('Teruskan'),
              onTap: () {
                Navigator.pop(ctx);
                _showForwardDialog(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Forward message dialog
  void _showForwardDialog(Message message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final allChats = chatProvider.chats;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teruskan ke...'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: allChats.isEmpty
              ? const Center(child: Text('Tidak ada chat'))
              : ListView.builder(
                  itemCount: allChats.length,
                  itemBuilder: (context, index) {
                    final target = allChats[index];
                    if (target.id == chat.id) return const SizedBox.shrink();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          target.sender.isNotEmpty ? target.sender[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      title: Text(target.sender),
                      subtitle: Text(target.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Meneruskan pesan ke ${target.sender}...')),
                        );
                        
                        final request = MessageRequest(
                          receiver: target.id,
                          content: message.content,
                        );
                        final resp = await _chatService.sendMessage(request);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(resp.isError ? 'Gagal meneruskan pesan' : 'Pesan berhasil diteruskan ke ${target.sender}'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  /// Forward multiple messages dialog
  void _showForwardSelectedDialog() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final allChats = chatProvider.chats;
    
    // Simpan list pesan yang di-select secara urut waktu
    final sortedIndices = _selectedMessageIndices.toList()..sort();
    final selectedMessages = sortedIndices.map((i) => _messages[i]).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teruskan ke...'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: allChats.isEmpty
              ? const Center(child: Text('Tidak ada chat'))
              : ListView.builder(
                  itemCount: allChats.length,
                  itemBuilder: (context, index) {
                    final target = allChats[index];
                    if (target.id == chat.id) return const SizedBox.shrink();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          target.sender.isNotEmpty ? target.sender[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      title: Text(target.sender),
                      subtitle: Text(target.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Meneruskan ${selectedMessages.length} pesan ke ${target.sender}...')),
                        );
                        
                        bool hasError = false;
                        for (final msg in selectedMessages) {
                          final request = MessageRequest(
                            receiver: target.id,
                            content: msg.content,
                          );
                          final resp = await _chatService.sendMessage(request);
                          if (resp.isError) hasError = true;
                        }

                        if (mounted) {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedMessageIndices.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(hasError ? 'Beberapa pesan gagal diteruskan' : 'Pesan berhasil diteruskan ke ${target.sender}'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  "No more messages" header
  // ─────────────────────────────────────────────

  Widget _buildNoMoreMessages() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(
        'No more messages',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  System message (centered with dividers)
  // ─────────────────────────────────────────────

  Widget _buildSystemMessage(Message message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[400], thickness: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[400], thickness: 0.5)),
            ],
          ),
          if (message.time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.time,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Chat Bubble — matching screenshot style
  // ─────────────────────────────────────────────

  Widget _buildChatBubble(Message message, bool isDark) {
    final isMe = message.isMe;

    // Image message bubble
    if (message.messageType == MessageType.image) {
      return _buildImageBubble(message, isDark);
    }

    // Voice message bubble
    if (message.messageType == MessageType.voice) {
      return _buildVoiceBubble(message, isDark);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.blue
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Quoted / reply
            if (message.repliedMessage != null) ...[
              _buildQuotedMessage(message.repliedMessage!, isMe),
              const SizedBox(height: 6),
            ],
            // Content
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            // Time + status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white70
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _getStatusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  VOICE MESSAGE BUBBLE
  // ─────────────────────────────────────────────

  Widget _buildVoiceBubble(Message message, bool isDark) {
    final isMe = message.isMe;
    final isThisPlaying = _isPlaying && _currentlyPlayingPath == message.audioPath;
    final progress = _playbackDuration.inMilliseconds > 0 && isThisPlaying
        ? _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds
        : 0.0;

    final displayDuration = isThisPlaying
        ? _formatDuration(_playbackPosition.inSeconds)
        : _formatDuration(message.audioDuration);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.blue
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause button
                GestureDetector(
                  onTap: message.audioPath != null
                      ? () => _togglePlayback(message.audioPath!)
                      : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isThisPlaying ? Icons.pause : Icons.play_arrow,
                      color: isMe ? Colors.white : Colors.blue,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Waveform / progress bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Simulated waveform bars
                      SizedBox(
                        height: 28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(20, (i) {
                            final barProgress = (i + 1) / 20;
                            final isActive = progress >= barProgress;
                            // Pseudo-random heights for waveform look
                            final heights = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.3, 1.0, 0.5, 0.7,
                                              0.6, 0.9, 0.4, 0.8, 0.5, 0.7, 0.3, 0.6, 0.8, 0.5];
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                height: 28 * heights[i],
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (isMe ? Colors.white : Colors.blue)
                                      : (isMe ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Mic icon
                Icon(
                  Icons.mic,
                  size: 18,
                  color: isMe ? Colors.white70 : Colors.grey[500],
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Duration + time + status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayDuration,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message.time,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _getStatusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  IMAGE MESSAGE BUBBLE
  // ─────────────────────────────────────────────

  Widget _buildImageBubble(Message message, bool isDark) {
    final isMe = message.isMe;

    Widget imageWidget;
    if (message.imagePath != null && File(message.imagePath!).existsSync()) {
      imageWidget = Image.file(
        File(message.imagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    } else if (message.imageUrl != null && message.imageUrl!.startsWith('http')) {
      imageWidget = Image.network(
        message.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                color: isMe ? Colors.white : Colors.blue,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    } else {
      imageWidget = _buildImagePlaceholder();
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.blue
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image with rounded top corners
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 280,
                  minHeight: 120,
                ),
                child: imageWidget,
              ),
            ),
            // Time + status row below image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.time,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white70
                          : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _getStatusIcon(message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text('Image', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  INPUT BAR — matching screenshot
  // ─────────────────────────────────────────────

  Widget _buildInputBar(bool isDark) {
    // Attachment panel or spacing
    final bottomPadding = MediaQuery.of(context).padding.bottom + 8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment icon on the left (toggle panel)
          IconButton(
            icon: Icon(
              _showAttachmentPanel ? Icons.close : Icons.attach_file,
              color: Colors.blue,
              size: 26,
            ),
            onPressed: _toggleAttachmentPanel,
          ),
          // Text field with emoji suffix
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 3,
              onTap: () {
                if (_showEmojiPicker) {
                  setState(() => _showEmojiPicker = false);
                }
              },
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: Colors.blue,
                    size: 26,
                  ),
                  onPressed: _toggleEmojiPicker,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Blue circular button: send (text) or hold-to-record (mic)
          _isComposing
              ? Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 22),
                    onPressed: _sendMessage,
                  ),
                )
              : GestureDetector(
                  onTap: _showVoiceBottomSheet,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 22),
                  ),
                ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  ATTACHMENT PANEL
  // ─────────────────────────────────────────────

  Widget _buildAttachmentPanel(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: const Color(0xFFFF5252),
                onTap: _pickAndSendFromCamera,
              ),
              _buildAttachmentOption(
                icon: Icons.photo,
                label: 'Gallery',
                color: const Color(0xFF7C4DFF),
                onTap: _pickAndSendImage,
              ),
              _buildAttachmentOption(
                icon: Icons.videocam,
                label: 'Video',
                color: const Color(0xFFE040FB),
                onTap: _pickAndSendVideo,
              ),
              _buildAttachmentOption(
              icon: Icons.insert_drive_file,
              label: 'Document',
              color: const Color(0xFF448AFF),
              onTap: _pickAndSendDocument,
            ),
            _buildAttachmentOption(
              icon: Icons.location_on,
              label: 'Location',
              color: const Color(0xFF66BB6A),
              onTap: _shareLocation,
            ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  RECORDING OVERLAY BAR
  // ─────────────────────────────────────────────

  // Removed _buildRecordingBar as it's replaced by VoiceRecordingBottomSheet

  // ─────────────────────────────────────────────
  //  EMOJI PICKER — WhatsApp style
  // ─────────────────────────────────────────────

  Widget _buildEmojiPicker(bool isDark) {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: _onEmojiSelected,
        onBackspacePressed: () {
          final text = _messageController.text;
          if (text.isNotEmpty) {
            // Handle multi-byte emoji characters properly
            final characters = text.characters.toList();
            characters.removeLast();
            _messageController.text = characters.join();
            _messageController.selection = TextSelection.collapsed(
              offset: _messageController.text.length,
            );
          }
        },
        config: Config(
          height: 250,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28,
            backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
            indicatorColor: Colors.blue,
            iconColorSelected: Colors.blue,
            iconColor: isDark ? Colors.grey[600]! : Colors.grey[400]!,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            showBackspaceButton: true,
            showSearchViewButton: true,
            backgroundColor: Colors.blue,
            buttonColor: Colors.white,
            buttonIconColor: Colors.white,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
            buttonIconColor: Colors.blue,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────

  Widget _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.cyanAccent);
    }
  }

  Widget _buildReplyPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Colors.blue, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _repliedMessage!.isMe ? 'You' : chat.sender,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _repliedMessage!.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => setState(() => _repliedMessage = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotedMessage(Message message, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : Colors.blue,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.isMe ? 'You' : chat.sender,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : Colors.blue,
              fontSize: 12,
            ),
          ),
          Text(
            message.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isMe ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Animated Chat Bubble
// ─────────────────────────────────────────────

class AnimatedChatBubble extends StatefulWidget {
  final Widget child;
  final bool isMe;

  const AnimatedChatBubble({
    super.key,
    required this.child,
    required this.isMe,
  });

  @override
  State<AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Custom Painter for Sidebar Icon
// ─────────────────────────────────────────────

class _SidebarIconPainter extends CustomPainter {
  final Color color;
  _SidebarIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = 2.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeJoin = StrokeJoin.round;

    // Outer rounded rectangle – small radius like the target
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(rect, paint);

    // Vertical divider — roughly in the middle (45 %)
    final dividerX = size.width * 0.45;
    canvas.drawLine(
      Offset(dividerX, 1),
      Offset(dividerX, size.height - 1),
      paint,
    );

    // Three horizontal lines on the RIGHT panel
    final rightPanelLeft = dividerX + 4;
    final rightPanelRight = size.width - 4;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final lineSpacing = 4.0;

    // Middle line
    canvas.drawLine(
      Offset(rightPanelLeft, centerY),
      Offset(rightPanelRight, centerY),
      linePaint,
    );
    // Top line
    canvas.drawLine(
      Offset(rightPanelLeft, centerY - lineSpacing),
      Offset(rightPanelRight, centerY - lineSpacing),
      linePaint,
    );
    // Bottom line
    canvas.drawLine(
      Offset(rightPanelLeft, centerY + lineSpacing),
      Offset(rightPanelRight, centerY + lineSpacing),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullscreenVideoPage extends StatefulWidget {
  final String videoUrl;
  const _FullscreenVideoPage({required this.videoUrl});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Izinkan semua orientasi agar video portrait & landscape
    // sama-sama fullscreen mengikuti ukuran asli video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _initVideoWithCache();
  }

  Future<void> _initVideoWithCache() async {
    try {
      final fileInfo = await DefaultCacheManager()
          .getSingleFile(widget.videoUrl);
      _controller = VideoPlayerController.file(fileInfo);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller!.play();
        _startHideTimer();
      }
    } catch (e) {
      _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller!.play();
        _startHideTimer();
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video memenuhi layar mengikuti ukuran asli video
            Center(
              child: (_isInitialized && _controller != null)
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            // Controls overlay (auto-hide setelah 3 detik)
            if (_isInitialized && _controller != null && _showControls) ...[
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                      _startHideTimer();
                    }
                  });
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  Future<void> _initThumbnail() async {
    try {
      final fileInfo = await DefaultCacheManager()
          .getSingleFile(widget.videoUrl);
      _controller = VideoPlayerController.file(fileInfo);
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullscreenVideoPage(
              videoUrl: widget.videoUrl,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail ukuran mengikuti ukuran asli video
          AspectRatio(
            aspectRatio: (_isInitialized && _controller != null)
                ? _controller!.value.size.width /
                    _controller!.value.size.height
                : 1.0, // fallback square jika belum init
            child: (_isInitialized && _controller != null)
                ? VideoPlayer(_controller!)
                : Container(color: Colors.black87),
          ),
          // Tombol play selalu tampil di thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
