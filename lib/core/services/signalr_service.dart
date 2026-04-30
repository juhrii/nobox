import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_config.dart';

/// SignalR service for real-time messaging via the NoBox messagehub.
///
/// Listens to these server events:
/// - TerimaPesan: incoming chat message
/// - TerimaSubSpv: room/conversation data update
/// - UcChanged: total unread count changed
/// - TerimaExpired: session expired
class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ── NoBox Server Event Names ──
  static const String eventTerimaPesan = 'TerimaPesan';
  static const String eventTerimaSubSpv = 'TerimaSubSpv';
  static const String eventUcChanged = 'UcChanged';
  static const String eventTerimaExpired = 'TerimaExpired';

  // ── Generic stream (backward-compatible) ──
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReceived => _messageController.stream;

  // ── Typed streams for specific events ──
  final _terimaPesanController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTerimaPesan => _terimaPesanController.stream;

  final _terimaSubSpvController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTerimaSubSpv => _terimaSubSpvController.stream;

  final _ucChangedController = StreamController<int>.broadcast();
  Stream<int> get onUcChanged => _ucChangedController.stream;

  // ── Connection state stream ──
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  /// Connect to the SignalR hub with the user's auth token.
  Future<void> connect() async {
    if (_isConnected && _hubConnection != null) {
      debugPrint('SignalR: Already connected');
      return;
    }

    try {
      debugPrint('SignalR: Connecting to ${AppConfig.signalRUrl}...');

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            AppConfig.signalRUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async {
                // Always read fresh token (handles token refresh/expiry)
                const storage = FlutterSecureStorage();
                return await storage.read(key: 'auth_token') ?? '';
              },
            ),
          )
          .withAutomaticReconnect()
          .build();

      // ── Register handlers for NoBox events ──
      _hubConnection!.on(eventTerimaPesan, _handleTerimaPesan);
      _hubConnection!.on(eventTerimaSubSpv, _handleTerimaSubSpv);
      _hubConnection!.on(eventUcChanged, _handleUcChanged);
      _hubConnection!.on(eventTerimaExpired, _handleTerimaExpired);

      // ── Connection state handlers ──
      _hubConnection!.onclose(({error}) {
        debugPrint('SignalR: Connection closed. Error: $error');
        _isConnected = false;
        _connectionStateController.add(false);
      });

      _hubConnection!.onreconnecting(({error}) {
        debugPrint('SignalR: Reconnecting... Error: $error');
        _isConnected = false;
        _connectionStateController.add(false);
      });

      _hubConnection!.onreconnected(({connectionId}) {
        debugPrint('SignalR: Reconnected! ConnectionId: $connectionId');
        _isConnected = true;
        _connectionStateController.add(true);
      });

      // Start the connection
      await _hubConnection!.start();
      _isConnected = true;
      _connectionStateController.add(true);
      debugPrint('SignalR: ✅ Connected successfully!');
      debugPrint('SignalR: ConnectionId = ${_hubConnection!.connectionId}');
      debugPrint('SignalR: Listening for: $eventTerimaPesan, $eventTerimaSubSpv, $eventUcChanged, $eventTerimaExpired');

    } catch (e, stack) {
      debugPrint('SignalR: ❌ Connection failed: $e');
      debugPrint('Stack: $stack');
      _isConnected = false;
      _connectionStateController.add(false);
    }
  }

  // ══════════════════════════════════════════════
  //  Event Handlers
  // ══════════════════════════════════════════════

  /// Handle incoming chat message (TerimaPesan).
  ///
  /// args[0] = "RoomId{id}" (String with prefix)
  /// args[1] = JSON string of message data ({Id, RoomId, Msg, From, To, Type, Files, ...})
  /// args[2] = 0 (int)
  /// args[3] = JSON string of sender info ({Name, Photo}) — optional
  void _handleTerimaPesan(List<Object?>? arguments) {
    if (arguments == null || arguments.length < 2) {
      debugPrint('SignalR: TerimaPesan - invalid arguments (length: ${arguments?.length})');
      return;
    }

    try {
      // Extract room ID from "RoomId794312812470277" format
      final roomIdRaw = arguments[0]?.toString() ?? '';
      final roomId = roomIdRaw.replaceFirst('RoomId', '');

      // Parse message JSON
      Map<String, dynamic> messageData = {};
      if (arguments[1] is String) {
        messageData = jsonDecode(arguments[1] as String) as Map<String, dynamic>;
      } else if (arguments[1] is Map) {
        messageData = Map<String, dynamic>.from(arguments[1] as Map);
      }

      // Parse sender info (optional, args[3])
      Map<String, dynamic>? senderData;
      if (arguments.length > 3 && arguments[3] is String) {
        try {
          senderData = jsonDecode(arguments[3] as String) as Map<String, dynamic>;
        } catch (_) {}
      }

      final parsed = {
        'roomId': roomId,
        'message': messageData,
        'sender': senderData,
      };

      debugPrint('SignalR: 📩 TerimaPesan | room=$roomId | msg=${messageData['Msg']}');

      // Emit to typed stream
      _terimaPesanController.add(parsed);

      // Emit to generic stream — put parsed messageData as args[0]
      // so existing consumers can access RoomId, Msg, In, etc.
      _messageController.add({
        'method': eventTerimaPesan,
        'arguments': [messageData],
        'parsed': parsed,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SignalR: ❌ Error parsing TerimaPesan: $e');
    }
  }

  /// Handle room/subscription update (TerimaSubSpv).
  ///
  /// args[0] = tenantId (int)
  /// args[1] = JSON string of room data ({Id, St, Ct, LastMsg, Uc, TimeMsg, ...})
  void _handleTerimaSubSpv(List<Object?>? arguments) {
    if (arguments == null || arguments.length < 2) {
      debugPrint('SignalR: TerimaSubSpv - invalid arguments (length: ${arguments?.length})');
      return;
    }

    try {
      final tenantId = arguments[0]?.toString() ?? '';

      Map<String, dynamic> roomData = {};
      if (arguments[1] is String) {
        roomData = jsonDecode(arguments[1] as String) as Map<String, dynamic>;
      } else if (arguments[1] is Map) {
        roomData = Map<String, dynamic>.from(arguments[1] as Map);
      }

      final parsed = {
        'tenantId': tenantId,
        'room': roomData,
      };

      debugPrint('SignalR: 🏠 TerimaSubSpv | room=${roomData['Id']} | lastMsg=${roomData['LastMsg']} | uc=${roomData['Uc']}');

      // Emit to typed stream
      _terimaSubSpvController.add(parsed);

      // Emit to generic stream
      _messageController.add({
        'method': eventTerimaSubSpv,
        'arguments': [roomData],
        'parsed': parsed,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SignalR: ❌ Error parsing TerimaSubSpv: $e');
    }
  }

  /// Handle unread count change (UcChanged).
  ///
  /// args[0] = total unread count (int)
  void _handleUcChanged(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      final count = arguments[0] is int
          ? arguments[0] as int
          : int.tryParse(arguments[0].toString()) ?? 0;

      debugPrint('SignalR: 🔢 UcChanged: $count');

      // Emit to typed stream
      _ucChangedController.add(count);

      // Emit to generic stream
      _messageController.add({
        'method': eventUcChanged,
        'arguments': arguments,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SignalR: ❌ Error parsing UcChanged: $e');
    }
  }

  /// Handle session expired (TerimaExpired).
  ///
  /// args[0] = roomId
  /// args[1] = timestamp (String)
  /// args[2] = message (String)
  /// args[3] = bool
  void _handleTerimaExpired(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      debugPrint('SignalR: ⏰ TerimaExpired | room=${arguments[0]}');

      _messageController.add({
        'method': eventTerimaExpired,
        'arguments': arguments,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SignalR: ❌ Error parsing TerimaExpired: $e');
    }
  }

  // ══════════════════════════════════════════════
  //  Client → Server Methods
  // ══════════════════════════════════════════════

  /// Invoke a method on the hub (fire-and-forget).
  Future<void> invoke(String methodName, {List<Object>? args}) async {
    if (!_isConnected || _hubConnection == null) {
      debugPrint('SignalR: Cannot invoke "$methodName" — not connected');
      throw Exception('SignalR not connected');
    }
    try {
      debugPrint('SignalR: Sending "$methodName" with args: $args');
      await _hubConnection!.send(methodName, args: args);
      debugPrint('SignalR: ✅ "$methodName" sent successfully');
    } catch (e) {
      debugPrint('SignalR: ❌ Error sending "$methodName": $e');
      rethrow;
    }
  }

  /// Mark messages as read for a room (sends ReadMsgCount to server).
  Future<void> sendReadCount(int roomId) async {
    try {
      await invoke('ReadMsgCount', args: [roomId]);
    } catch (e) {
      debugPrint('SignalR: Failed to send ReadMsgCount for room $roomId: $e');
    }
  }

  /// Disconnect from the hub.
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _isConnected = false;
      _connectionStateController.add(false);
      debugPrint('SignalR: Disconnected');
    }
  }

  /// Dispose resources.
  void dispose() {
    _messageController.close();
    _terimaPesanController.close();
    _terimaSubSpvController.close();
    _ucChangedController.close();
    _connectionStateController.close();
    disconnect();
  }
}
