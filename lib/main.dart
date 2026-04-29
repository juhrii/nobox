import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/chat_status_provider.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/chat_settings_provider.dart';
import 'core/providers/locale_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/signalr_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/utils/app_routes.dart';
import 'presentation/screens/splash/splash_page.dart';
import 'presentation/screens/auth/login_page.dart';
import 'presentation/screens/chat/chat_list_page.dart';
import 'presentation/screens/chat/chat_detail_page.dart';
import 'presentation/screens/chat/archive_list_page.dart';
import 'core/utils/globals.dart';

void main() {
  debugPrint('App: main started');
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ChatStatusProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => ChatSettingsProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('App: Fatal error during startup: $e');
    debugPrint(stack.toString());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _signalRSubscription;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Timer? _messagePollingTimer;
  Map<String, String> _lastKnownTimes = {}; // roomId -> lastMessageTime
  bool _isFirstPoll = true;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    // Observe app lifecycle (foreground/background)
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Firebase and PushNotifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await PushNotificationService.initialize();
      } catch (e) {
        debugPrint('Firebase init failed (maybe google-services.json is missing): $e');
      }
      _subscribeToSignalR();
      _startMessagePolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    debugPrint('Main: App lifecycle state = $state');
  }

  bool get _isAppInBackground =>
      _appLifecycleState == AppLifecycleState.paused ||
      _appLifecycleState == AppLifecycleState.inactive ||
      _appLifecycleState == AppLifecycleState.hidden;

  void _subscribeToSignalR() {
    final signalR = SignalRService();
    
    _signalRSubscription = signalR.onMessageReceived.listen((data) {
      debugPrint('Main: SignalR message received: ${data['method']}');
      
      final method = data['method']?.toString() ?? '';
      final arguments = data['arguments'] as List<dynamic>?;

      // Show notification for incoming messages
      if (method.toLowerCase().contains('message') || 
          method.toLowerCase().contains('receive') ||
          method.toLowerCase().contains('notify') ||
          method.toLowerCase().contains('inbox')) {
        
        String title = 'New Message';
        String body = '';
        String conversationId = 'default_chat_id';

        if (arguments != null && arguments.isNotEmpty) {
          // Try to extract sender name and message content
          final firstArg = arguments[0];
          if (firstArg is Map) {
            title = firstArg['SenderName']?.toString() ?? 
                    firstArg['From']?.toString() ?? 
                    firstArg['Name']?.toString() ?? 
                    'New Message';
            body = firstArg['Message']?.toString() ?? 
                   firstArg['Body']?.toString() ?? 
                   firstArg['Content']?.toString() ?? 
                   'You have a new message';
            
            // Extract Conversation ID or Chat ID
            conversationId = firstArg['ConversationId']?.toString() ??
                             firstArg['ChatId']?.toString() ??
                             firstArg['RoomId']?.toString() ??
                             firstArg['Id']?.toString() ??
                             title.hashCode.toString();
          } else if (firstArg is String) {
            body = firstArg;
            conversationId = title.hashCode.toString();
          }
        }

        // Filter out outgoing messages (sent by us)
        bool isOurOwnMessage = false;
        if (arguments != null && arguments.isNotEmpty) {
          final firstArg = arguments[0];
          if (firstArg is Map) {
            // If AgentId is present and non-zero, it's an outgoing message
            final agentId = firstArg['AgentId'];
            if (agentId != null && agentId != 0 && agentId != '0') {
               isOurOwnMessage = true;
            }
            if (firstArg['IsMe'] == true) {
               isOurOwnMessage = true;
            }
          }
        }

        if (isOurOwnMessage) {
          debugPrint('Main: Skipping notification for our own message');
        } else {
          // Always show system push notification (heads-up floating)
          PushNotificationService.showChatNotification(
            roomId: conversationId,
            roomName: title,
            senderName: title,
            message: body,
          );
        }

        // Auto-refresh chat list by using a try-catch for Provider access over Navigation key context
        try {
          final chatProvider = context.read<ChatProvider>();
          chatProvider.refreshFirstPage();
        } catch (e) {
          debugPrint('Main: Could not refresh chats: $e');
        }
      }

      // Handle typing indicators
      if (method.toLowerCase().contains('typing')) {
        if (arguments != null && arguments.isNotEmpty) {
          final firstArg = arguments[0];
          String sender = '';
          bool isTyping = true;

          if (firstArg is Map) {
            sender = firstArg['SenderId']?.toString() ?? 
                     firstArg['From']?.toString() ?? '';
            isTyping = firstArg['IsTyping'] ?? true;
          } else if (firstArg is String) {
            sender = firstArg;
          }

          if (sender.isNotEmpty) {
            try {
              final statusProvider = context.read<ChatStatusProvider>();
              statusProvider.setTyping(sender, isTyping);
            } catch (e) {
              debugPrint('Main: Could not update typing: $e');
            }
          }
        }
      }

      // Handle online/presence status
      if (method.toLowerCase().contains('online') || 
          method.toLowerCase().contains('presence') ||
          method.toLowerCase().contains('status')) {
        if (arguments != null && arguments.isNotEmpty) {
          final firstArg = arguments[0];
          String sender = '';

          if (firstArg is Map) {
            sender = firstArg['UserId']?.toString() ?? 
                     firstArg['From']?.toString() ?? '';
          } else if (firstArg is String) {
            sender = firstArg;
          }

          if (sender.isNotEmpty) {
            try {
              final statusProvider = context.read<ChatStatusProvider>();
              statusProvider.setOnline(sender);
            } catch (e) {
              debugPrint('Main: Could not update online status: $e');
            }
          }
        }
      }
    });
  }

  // ── Message Polling for Notifications ──
  void _startMessagePolling() {
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollForNewMessages();
    });
    debugPrint('🔄 Message polling started (every 15s)');
  }

  Future<void> _pollForNewMessages() async {
    if (_isPolling) return;
    _isPolling = true;
    
    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.refreshFirstPage();
      
      // If this is the very first time we see data, build the baseline and exit
      if (_isFirstPoll && chatProvider.chats.isNotEmpty) {
        for (final chat in chatProvider.chats) {
          _lastKnownTimes[chat.id] = chat.time;
        }
        _isFirstPoll = false;
        debugPrint('🔄 Baseline polling state initialized for ${chatProvider.chats.length} chats');
        return;
      }
      
      for (final chat in chatProvider.chats) {
        final lastTime = _lastKnownTimes[chat.id];
        
        // Detect new message: time changed (meaning a new message was added/received)
        final hasNewMessage = lastTime != null && lastTime != chat.time;
        
        // Detect brand new conversation that wasn't in baseline
        final isNewConversation = lastTime == null && !_isFirstPoll;
        
        if (hasNewMessage || isNewConversation) {
          // Don't notify if user is currently in this chat
          // Also check if the new message is possibly our own to avoid self-notifications,
          // though without a clear 'isMe' flag on ChatModel at the list level, 
          // relying strictly on currentRoomId is the safest fallback.
          // Don't notify if user is currently in this chat
          // Also check if the new message is possibly our own to avoid self-notifications
          final shouldNotify = PushNotificationService.currentRoomId != chat.id && !chat.isLastMessageFromMe;
          
          if (shouldNotify) {
            debugPrint('🔔 New message detected in ${chat.sender}: ${chat.lastMessage}');
            await PushNotificationService.showChatNotification(
              roomId: chat.id,
              roomName: chat.sender,
              senderName: chat.sender,
              message: chat.lastMessage,
            );
          } else if (chat.isLastMessageFromMe) {
            debugPrint('Main: Polling detected new message but it is from us, skipping notification');
          }
        }
        
        // Update last known state
        _lastKnownTimes[chat.id] = chat.time;
      }
    } catch (e) {
      debugPrint('🔄 Polling error: $e');
    } finally {
      _isPolling = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signalRSubscription?.cancel();
    _messagePollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp: build called');
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NoBox Chat',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: navigatorKey,
          home: const SplashPage(),
          routes: {
            AppRoutes.login: (_) => const LoginPage(),
            AppRoutes.home: (_) => const ChatListPage(),
            AppRoutes.chatDetail: (_) => const ChatDetailPage(),
            AppRoutes.archivedChats: (_) => const ArchiveListPage(),

          },
        );
      },
    );
  }
}
