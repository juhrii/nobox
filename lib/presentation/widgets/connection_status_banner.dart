import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/signalr_service.dart';

/// Displays a banner when connection is lost, with auto-reconnect.
/// Only shows AFTER at least one successful connection (avoids showing
/// on first startup when SignalR hasn't connected yet).
class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<bool> _connectionSub;
  bool _isConnected = true;
  bool _isReconnecting = false;
  bool _hasEverConnected = false; // only show banner after first connect
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    final signalR = SignalRService();
    _isConnected = signalR.isConnected;
    if (_isConnected) _hasEverConnected = true;

    _connectionSub = signalR.onConnectionStateChanged.listen((connected) {
      if (mounted) {
        setState(() {
          if (connected) {
            _hasEverConnected = true;
            _isReconnecting = false;
          }
          _isConnected = connected;
        });
      }
    });
  }

  void _reconnect() async {
    setState(() => _isReconnecting = true);
    try {
      await SignalRService().connect();
    } catch (_) {}
    if (mounted && !_isConnected) {
      setState(() => _isReconnecting = false);
    }
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if connected, or if we haven't ever connected yet
    if (_isConnected || !_hasEverConnected) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _isReconnecting
            ? Colors.orange.shade600
            : Colors.red.shade600,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: _isReconnecting
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    )
                  : FadeTransition(
                      opacity: Tween<double>(begin: 0.5, end: 1.0)
                          .animate(_pulseController),
                      child: const Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isReconnecting
                    ? 'Menghubungkan kembali...'
                    : 'Koneksi terputus',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!_isReconnecting)
              GestureDetector(
                onTap: _reconnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
