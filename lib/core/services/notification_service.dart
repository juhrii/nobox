import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import '../utils/globals.dart';

class NotificationService {
  static final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Chat ID yang saat ini sedang dibuka dilayar (aktif)
  static String? activeChatId;

  /// Menyimpan buffer history pesan (ConversationId -> List<Message>) 
  /// agar pesan bisa menumpuk cantik di notifikasi
  static final Map<String, List<fln.Message>> _unreadMessages = {};

  /// Initialize the local notifications plugin.
  /// Call this once at app startup.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Gunakan 'launcher_icon' (nama resource yang valid, tanpa @mipmap prefiks)
    const androidSettings = fln.AndroidInitializationSettings('launcher_icon');

    const iosSettings = fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = fln.InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android (high importance = heads-up)
    const androidChannel = fln.AndroidNotificationChannel(
      'nobox_messages', // channel id
      'Pesan Masuk', // channel name
      description: 'Notifikasi pesan masuk NoBox Chat',
      importance: fln.Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request permission untuk Android 13+
    await _requestPermission();

    _isInitialized = true;
    debugPrint('NotificationService: ✅ Initialized');
  }

  static Future<void> _requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('NotificationService: Permission granted = $granted');
    }
  }

  static void _onNotificationTapped(fln.NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped: ${response.payload}');
    // Di masa depan bisa tambahkan navigasi otomatis ke ChatDetailPage lewat context
    if (response.payload != null && response.payload!.isNotEmpty) {
      clearNotification(response.payload!); // Hapus notifikasi setelah ditekan
    }
  }

  /// Menghapus history notifikasi untuk chat tertentu (saat dibuka/dibaca)
  static void clearNotification(String conversationId) {
    _unreadMessages.remove(conversationId);
    _plugin.cancel(conversationId.hashCode);
  }

  /// Tampilkan notifikasi system (floating foreground/background).
  /// Fitur: Menumpuk riwayat pesan dari orang yang sama,
  /// Mencegah muncul ganda jika halaman chat sedang aktif dibuka.
  static Future<void> showPushNotification(
    String conversationId,
    String senderName,
    String body,
  ) async {
    if (!_isInitialized) {
      debugPrint('NotificationService: Not initialized yet');
      return;
    }

    // CEK 1: Apakah user SEDANG membuka chat ini?
    // Jika ya, BATAL tampilkan notifikasi. (Untuk mencegah notif mengganggu saat asik berbalas chat)
    if (activeChatId == conversationId) {
      debugPrint('NotificationService: Chat is Active. Suppression notification.');
      return;
    }

    // Akumulasikan pesan ke dalam memory
    _unreadMessages.putIfAbsent(conversationId, () => []);

    final personObj = fln.Person(
      name: senderName,
      key: conversationId, // Grouping key by conversation
    );

    _unreadMessages[conversationId]!.add(
      fln.Message(body, DateTime.now(), personObj),
    );

    // Membuat style tampilan pesan menumpuk ala WhatsApp
    final messagingStyle = fln.MessagingStyleInformation(
      personObj, // Current 'Me' / recipient
      conversationTitle: senderName, // Name of sender/group title
      messages: _unreadMessages[conversationId]!,
    );

    final androidDetails = fln.AndroidNotificationDetails(
      'nobox_messages',
      'Pesan Masuk',
      channelDescription: 'Notifikasi pesan masuk',
      importance: fln.Importance.max,
      priority: fln.Priority.max,
      showWhen: true,
      icon: 'launcher_icon', // Harus match dengan resource name yang valid
      category: fln.AndroidNotificationCategory.message,
      visibility: fln.NotificationVisibility.public,
      styleInformation: messagingStyle,
      setAsGroupSummary: true,
      groupKey: 'com.nobox.chat.MESSAGES',
    );

    const iosDetails = fln.DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = fln.NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Gunakan hash dari conversationId sebagai Unique ID dari notification ini
    // Sehingga kalau ada pesan baru di percakapan yg sama, notifikasinya akan di UPDATE alih-alih ditambah baru.
    final id = conversationId.hashCode;

    await _plugin.show(
      id,
      senderName,
      body,
      notificationDetails,
      payload: conversationId,
    );

    debugPrint('NotificationService: 📢 Shown push notification for "$senderName"');
  }
}
