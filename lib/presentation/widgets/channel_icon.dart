import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// =====================================================================
// FITUR: Ikon Saluran (Channel)
// FILE: lib/presentation/widgets/channel_icon.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menampilkan ikon sumber obrolan (WhatsApp, Telegram, IG, dll.) berdasarkan channel ID.
// =====================================================================
class ChannelIcon extends StatelessWidget {
  final String chId;
  final String? channelName;
  final double size;
  final Color? color;
  final bool isWhite;

  const ChannelIcon({
    super.key,
    required this.chId,
    this.channelName,
    this.size = 14,
    this.color,
    this.isWhite = false,
  });

  @override
  // [ACTION: RENDER_CHANNEL_ICON] - Menggambar ikon berdasarkan nama saluran
  Widget build(BuildContext context) {
    final int channelId = int.tryParse(chId) ?? 0;
    final String cName = channelName?.toLowerCase() ?? '';

    String? assetName;

    // Determine asset base name
    if (channelId == 1 || channelId == 1557 || channelId == 1561 || cName.contains('whatsapp') || cName.contains('wa')) {
      assetName = 'wa';
    } else if (channelId == 2 || cName.contains('telegram')) {
      assetName = 'telegram';
    } else if (channelId == 3 || cName.contains('instagram') || cName.contains('ig')) {
      assetName = 'instagram';
    } else if (channelId == 4 || cName.contains('facebook') || cName.contains('fb')) {
      assetName = 'facebook';
    } else if (cName.contains('tiktok')) {
      assetName = 'tiktok';
    } else if (cName.contains('shopee')) {
      assetName = 'shopee';
    } else if (cName.contains('tokopedia') || cName.contains('toko pedia')) {
      assetName = 'Tokopedia';
    }

    if (assetName != null) {
      final String fullAssetName = isWhite ? '${assetName}_white.png' : '$assetName.png';
      return Image.asset(
        'assets/$fullAssetName',
        width: size,
        height: size,
        color: color, // color is usually null if we want to show original asset colors
        errorBuilder: (context, error, stackTrace) => Icon(Icons.chat_bubble_outline, size: size, color: color ?? Colors.grey),
      );
    }

    // Fallback if no matching asset
    return Icon(Icons.chat_bubble_outline, size: size, color: color ?? Colors.grey);
  }
}
