import 'package:flutter/material.dart';
import 'dart:math';

// =====================================================================
// FITUR: Kerangka Loading Balon Chat
// FILE: lib/presentation/widgets/message_shimmer_widget.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menampilkan animasi kerangka (shimmer) yang meniru bentuk balon chat saat ruang obrolan sedang memuat pesan.
// =====================================================================
class MessageShimmerWidget extends StatefulWidget {
  const MessageShimmerWidget({super.key});

  @override
  State<MessageShimmerWidget> createState() => _MessageShimmerWidgetState();
}

class _MessageShimmerWidgetState extends State<MessageShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Generate a fixed pattern of fake bubbles to look realistic
    final patterns = [
      {'isMe': false, 'lines': 2, 'width': 0.6},
      {'isMe': false, 'lines': 1, 'width': 0.4},
      {'isMe': true, 'lines': 3, 'width': 0.7},
      {'isMe': false, 'lines': 1, 'width': 0.5},
      {'isMe': true, 'lines': 1, 'width': 0.3},
      {'isMe': true, 'lines': 2, 'width': 0.5},
    ];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: patterns.length,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final pattern = patterns[index];
            final isMe = pattern['isMe'] as bool;
            final widthFactor = pattern['width'] as double;
            final lines = pattern['lines'] as int;

            return _buildShimmerBubble(isDark, isMe, widthFactor, lines);
          },
        );
      },
    );
  }

  Widget _buildShimmerBubble(bool isDark, bool isMe, double widthFactor, int lines) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = screenWidth * widthFactor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildShimmerCircle(32, isDark),
            const SizedBox(width: 8),
          ],
          Container(
            width: bubbleWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              gradient: LinearGradient(
                begin: Alignment(_animation.value - 1, 0),
                end: Alignment(_animation.value + 1, 0),
                colors: isDark
                    ? [
                        Colors.grey.shade800,
                        Colors.grey.shade700,
                        Colors.grey.shade800,
                      ]
                    : [
                        Colors.grey.shade300,
                        Colors.grey.shade100,
                        Colors.grey.shade300,
                      ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(lines, (index) {
                // Make the last line slightly shorter for realism
                final isLastLine = index == lines - 1;
                return Container(
                  height: 12,
                  width: isLastLine ? bubbleWidth * 0.6 : bubbleWidth,
                  margin: EdgeInsets.only(bottom: isLastLine ? 0 : 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade600.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildShimmerCircle(16, isDark), // Read receipt placeholder
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerCircle(double size, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment(_animation.value - 1, 0),
          end: Alignment(_animation.value + 1, 0),
          colors: isDark
              ? [
                  Colors.grey.shade800,
                  Colors.grey.shade700,
                  Colors.grey.shade800,
                ]
              : [
                  Colors.grey.shade300,
                  Colors.grey.shade100,
                  Colors.grey.shade300,
                ],
        ),
      ),
    );
  }
}
