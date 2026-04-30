import 'dart:async';
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
  StreamSubscription<Map<String, dynamic>>? _terimaPesanSub;
  StreamSubscription<Map<String, dynamic>>? _terimaSubSpvSub;
  StreamSubscription<int>? _ucChangedSub;
  StreamSubscription<bool>? _reconnectSub;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Timer? _messagePollingTimer;
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
    final wasPaused = _appLifecycleState == AppLifecycleState.paused ||
        _appLifecycleState == AppLifecycleState.hidden;
    _appLifecycleState = state;
    debugPrint('Main: App lifecycle state = $state');

    // Stop polling in background, restart when resumed
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _messagePollingTimer?.cancel();
      _messagePollingTimer = null;
      debugPrint('🔄 Polling stopped (app in background)');
    } else if (state == AppLifecycleState.resumed && wasPaused) {
      _startMessagePolling();
      // Sync data that might have been missed while backgrounded
      try {
        context.read<ChatProvider>().refreshFirstPage();
      } catch (_) {}
    }
  }

  void _subscribeToSignalR() {
    final signalR = SignalRService();

    // ── TerimaPesan: incoming chat message → show notification ──
    _terimaPesanSub = signalR.onTerimaPesan.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      final message = data['message'] as Map<String, dynamic>? ?? {};
      final sender = data['sender'] as Map<String, dynamic>?;
      final msgText = message['Msg']?.toString() ?? '';
      final senderName = sender?['Name']?.toString() ?? 'Pesan Baru';
      final agentId = message['AgentId'];

      debugPrint('Main: TerimaPesan | room=$roomId | sender=$senderName | msg=$msgText');

      // Skip our own outgoing messages
      final isOurOwnMessage = agentId != null && agentId != 0 && agentId.toString() != '0';

      if (!isOurOwnMessage) {
        // Only show notification if user is NOT in this room
        final isInRoom = PushNotificationService.currentRoomId == roomId;
        if (!isInRoom && msgText.isNotEmpty) {
          PushNotificationService.showChatNotification(
            roomId: roomId,
            roomName: senderName,
            senderName: senderName,
            message: msgText,
          );
        }
      }
    });

    // ── TerimaSubSpv: room data update → update chat list directly ──
    _terimaSubSpvSub = signalR.onTerimaSubSpv.listen((data) {
      final roomData = data['room'] as Map<String, dynamic>? ?? {};
      debugPrint('Main: TerimaSubSpv | room=${roomData['Id']}');

      try {
        final chatProvider = context.read<ChatProvider>();
        chatProvider.updateRoomFromSignalR(roomData);
      } catch (e) {
        debugPrint('Main: Could not update chat list from TerimaSubSpv: $e');
      }
    });

    // ── UcChanged: total unread count changed → refresh first page ──
    _ucChangedSub = signalR.onUcChanged.listen((count) {
      debugPrint('Main: UcChanged | total=$count');
      try {
        final chatProvider = context.read<ChatProvider>();
        chatProvider.refreshFirstPage();
      } catch (e) {
        debugPrint('Main: Could not refresh from UcChanged: $e');
      }
    });

    // ── Reconnect: sync data after reconnection ──
    _reconnectSub = signalR.onConnectionStateChanged.listen((connected) {
      if (connected) {
        debugPrint('Main: SignalR reconnected, syncing data...');
        try {
          context.read<ChatProvider>().refreshFirstPage();
        } catch (_) {}
      }
    });
  }

  // ── Safety-net Polling (data sync only, NO notifications) ──
  void _startMessagePolling() {
    _messagePollingTimer?.cancel();
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _pollForNewMessages();
    });
    debugPrint('🔄 Safety-net polling started (every 60s)');
  }

  Future<void> _pollForNewMessages() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      // Data sync only — no notifications (SignalR handles those)
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.refreshFirstPage();
    } catch (e) {
      debugPrint('🔄 Polling error: $e');
    } finally {
      _isPolling = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _terimaPesanSub?.cancel();
    _terimaSubSpvSub?.cancel();
    _ucChangedSub?.cancel();
    _reconnectSub?.cancel();
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
