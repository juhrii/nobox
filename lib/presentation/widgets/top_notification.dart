import 'dart:async';
import 'package:flutter/material.dart';

// =====================================================================
// FITUR: Top Floating Notification (Pop-up di Atas Layar)
// FILE: lib/presentation/widgets/top_notification.dart
// FUNGSI: Menampilkan notifikasi / peringatan error atau sukses di bagian atas layar
//         dengan animasi slide-down yang halus, swipe-to-dismiss, dan auto-dismiss.
// =====================================================================

class TopNotification {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    String? title,
    required String message,
    bool isError = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    dismissImmediately();

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopNotificationWidget(
        title: title,
        message: message,
        isError: isError,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismissImmediately() {
    if (_currentEntry != null) {
      if (_currentEntry!.mounted) {
        _currentEntry!.remove();
      }
      _currentEntry = null;
    }
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String? title;
  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  final Duration duration;

  const _TopNotificationWidget({
    this.title,
    required this.message,
    required this.isError,
    required this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _timer = Timer(widget.duration, () {
      _hide();
    });
  }

  void _hide() {
    _timer?.cancel();
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dismissible(
                key: const ValueKey('top_notification_key'),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _timer?.cancel();
                  widget.onDismiss();
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.isError
                            ? [const Color(0xFFEF5350), const Color(0xFFD32F2F)]
                            : [const Color(0xFF66BB6A), const Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isError ? Colors.red : Colors.green)
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isError
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.title != null &&
                                  widget.title!.isNotEmpty) ...[
                                Text(
                                  widget.title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: widget.title != null ? 0.95 : 1.0,
                                  ),
                                  fontSize: widget.title != null ? 12 : 14,
                                  fontWeight: widget.title != null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _hide,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
