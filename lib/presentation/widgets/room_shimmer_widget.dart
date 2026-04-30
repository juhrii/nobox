import 'package:flutter/material.dart';

/// Shimmer skeleton loading effect for Chat Room List (Inbox)
/// Meniru tampilan daftar obrolan saat sedang dimuat
class RoomShimmerWidget extends StatefulWidget {
  final int itemCount;

  const RoomShimmerWidget({super.key, this.itemCount = 5});

  @override
  State<RoomShimmerWidget> createState() => _RoomShimmerWidgetState();
}

class _RoomShimmerWidgetState extends State<RoomShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: widget.itemCount,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return _buildRoomTile(isDark);
          },
        );
      },
    );
  }

  Widget _buildRoomTile(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar skeleton (circle)
          _buildShimmerCircle(48, isDark),
          const SizedBox(width: 12),

          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + time
                Row(
                  children: [
                    Expanded(child: _buildShimmerBox(120, 14, isDark)),
                    const SizedBox(width: 8),
                    _buildShimmerBox(50, 12, isDark),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 2: Last message preview
                _buildShimmerBox(200, 12, isDark),
                const SizedBox(height: 8),

                // Row 3: Tags + badge
                Row(
                  children: [
                    _buildShimmerBox(70, 10, isDark),
                    const Spacer(),
                    _buildShimmerBox(24, 24, isDark, borderRadius: 12),
                  ],
                ),
              ],
            ),
          ),
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
        gradient: _buildShimmerGradient(isDark),
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height, bool isDark,
      {double borderRadius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: _buildShimmerGradient(isDark),
      ),
    );
  }

  LinearGradient _buildShimmerGradient(bool isDark) {
    return LinearGradient(
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
    );
  }
}
