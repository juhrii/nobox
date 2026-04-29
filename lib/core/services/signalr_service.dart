import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_config.dart';

/// SignalR service for real-time messaging via the NoBox messagehub.
/// 
/// Phase 1: Discovery mode — logs ALL incoming hub method invocations 
/// to identify the correct method names for receiving messages.
class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Stream controller for incoming messages
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReceived => _messageController.stream;

  // Stream controller for connection state changes
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  // Known common SignalR hub method names to listen to
  static const List<String> _knownMethodNames = [
    'ReceiveMessage',
    'NewMessage', 
    'SendMessage',
    'MessageReceived',
    'OnMessage',
    'onReceive',
    'ReceiveChat',
    'ChatMessage',
    'Notify',
    'Notification',
    'UpdateChat',
    'InboxUpdate',
    'ReceiveInbox',
    'onNewMessage',
    'broadcastMessage',
    'receive',
    'message',
    'BroadcastMessage',
  ];

  /// Connect to the SignalR hub with the user's auth token.
  Future<void> connect() async {
    if (_isConnected && _hubConnection != null) {
      debugPrint('SignalR: Already connected');
      return;
    }

    try {
      // Get token from secure storage
      const secureStorage = FlutterSecureStorage();
      final token = await secureStorage.read(key: 'auth_token');
      
      if (token == null) {
        debugPrint('SignalR: No token available, cannot connect');
        return;
      }

      debugPrint('SignalR: Connecting to ${AppConfig.signalRUrl}...');

      // Build the hub connection
      // Use LongPolling transport for Windows desktop compatibility
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            AppConfig.signalRUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
            ),
          )
          .withAutomaticReconnect()
          .build();

      // Register handlers for ALL known method names (discovery mode)
      for (var methodName in _knownMethodNames) {
        _hubConnection!.on(methodName, (arguments) {
          debugPrint('╔══════════════════════════════════════════');
          debugPrint('║ SignalR HUB METHOD INVOKED: "$methodName"');
          debugPrint('║ Arguments count: ${arguments?.length ?? 0}');
          if (arguments != null) {
            for (var i = 0; i < arguments.length; i++) {
              debugPrint('║ Arg[$i]: ${arguments[i]}');
              debugPrint('║ Type: ${arguments[i].runtimeType}');
            }
          }
          debugPrint('╚══════════════════════════════════════════');

          // Emit to stream for UI consumption
          _messageController.add({
            'method': methodName,
            'arguments': arguments,
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
      }

      // Connection state handlers
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
      debugPrint('SignalR: Listening for ${_knownMethodNames.length} method names...');

    } catch (e, stack) {
      debugPrint('SignalR: ❌ Connection failed: $e');
      debugPrint('Stack: $stack');
      _isConnected = false;
      _connectionStateController.add(false);
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

  /// Invoke a method on the hub (for sending messages via SignalR).
  /// Uses send() (fire-and-forget) instead of invoke() (waits for response).
  Future<void> invoke(String methodName, {List<Object>? args}) async {
    if (!_isConnected || _hubConnection == null) {
      debugPrint('SignalR: Cannot invoke "$methodName" — not connected');
      throw Exception('SignalR not connected');
    }
    try {
      debugPrint('SignalR: Sending "$methodName" with args: $args');
      // Use send() instead of invoke() — fire-and-forget, matching web behavior
      await _hubConnection!.send(methodName, args: args);
      debugPrint('SignalR: ✅ "$methodName" sent successfully');
    } catch (e) {
      debugPrint('SignalR: ❌ Error sending "$methodName": $e');
      rethrow;
    }
  }

  /// Dispose resources.
  void dispose() {
    _messageController.close();
    _connectionStateController.close();
    disconnect();
  }
}
