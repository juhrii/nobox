import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_routes.dart';

// =====================================================================
// FITUR: Welcome Screen (Onboarding Carousel 3 Slide)
// FILE: lib/presentation/screens/welcome/welcome_page.dart
// FUNGSI: Menampilkan perkenalan fitur utama NoBox Chat (Omnichannel, 
//         Multimedia Voice/Chat, Label & Funnel & Pin Chat) bagi pengguna baru 
//         sebelum menuju halaman Login. Selalu menggunakan tema terang (putih).
// =====================================================================

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _slides = [
    const OnboardingItem(
      badge: 'OMNICHANNEL INBOX',
      title: 'Satu Aplikasi,\nSemua Saluran',
      description:
          'Kelola seluruh percakapan pelanggan dari WhatsApp, Telegram, Instagram, TikTok, hingga marketplace dalam satu kotak masuk terpadu.',
      illustrationType: IllustrationType.channels,
    ),
    const OnboardingItem(
      badge: 'REAL-TIME & MULTIMEDIA',
      title: 'Komunikasi Cepat\n& Tanpa Hambatan',
      description:
          'Kirim pesan suara (Voice Note), berkas dokumen, foto, hingga balasan cepat dengan sinkronisasi langsung berbasis SignalR.',
      illustrationType: IllustrationType.multimedia,
    ),
    const OnboardingItem(
      badge: 'LABEL, FUNNEL & PIN CHAT',
      title: 'Kategorikan Kontak\n& Sematkan Obrolan',
      description:
          'Tandai pelanggan dengan Label, pantau tahap transaksi lewat Funnel penjualan, serta sematkan (Pin) obrolan penting agar selalu berada di posisi teratas.',
      illustrationType: IllustrationType.organization,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logo & Tombol Lewati
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/nobox2.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.chat_bubble_rounded,
                          color: AppTheme.primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NoBox',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        '.Chat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Lewati',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Visual Illustration Box
                        Expanded(
                          flex: 6,
                          child: Center(
                            child: _buildIllustration(
                              slide.illustrationType,
                              size,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Badge Kategori
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            slide.badge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Judul Slide
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Deskripsi Singkat
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Section: Dots Indicator & Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 26 : 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  if (_currentPage < _slides.length - 1)
                    Row(
                      children: [
                        if (_currentPage > 0)
                          IconButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppTheme.textSecondary,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Lanjut',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _completeOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Mulai Sekarang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // VISUAL ILLUSTRATION BUILDER
  // =====================================================================
  Widget _buildIllustration(IllustrationType type, Size screenSize) {
    switch (type) {
      case IllustrationType.channels:
        return _buildChannelsIllustration();
      case IllustrationType.multimedia:
        return _buildMultimediaIllustration();
      case IllustrationType.organization:
        return _buildChatListIllustration();
    }
  }

  /// Visual Slide 1: Logo Channels Omnichannel NoBox
  Widget _buildChannelsIllustration() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.12),
            Colors.transparent,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Central NoBox Orb
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/nobox2.png',
                width: 56,
                height: 56,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.all_inbox_rounded,
                  color: AppTheme.primaryColor,
                  size: 44,
                ),
              ),
            ),
          ),

          // Satellite Channel Bubbles
          _buildChannelPill('assets/wa.png', 'WhatsApp', const Offset(-85, -60)),
          _buildChannelPill('assets/telegram.png', 'Telegram', const Offset(85, -55)),
          _buildChannelPill('assets/instagram.png', 'Instagram', const Offset(-90, 45)),
          _buildChannelPill('assets/tiktok.png', 'TikTok', const Offset(90, 40)),
          _buildChannelPill('assets/Tokopedia.png', 'Tokopedia', const Offset(0, 95)),
          _buildChannelPill('assets/shopee.png', 'Shopee', const Offset(0, -100)),
        ],
      ),
    );
  }

  Widget _buildChannelPill(String assetPath, String label, Offset offset) {
    return Transform.translate(
      offset: offset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              assetPath,
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visual Slide 2: Real-Time Chat & Multimedia Mockup
  Widget _buildMultimediaIllustration() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Message Bubble (Inbound Voice Note)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF), // Soft Blue tint
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          14,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 2.5,
                            height: (i % 3 + 1) * 6.0,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '0:15 / 0:45',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Agent Message Bubble (Outbound Text Reply)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Halo Kak, pesanan dikirim ya! ✨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.done_all_rounded,
                    color: Colors.white70,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Document attachment preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice_NoBox_102.pdf',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '240 KB • Selesai Terkirim',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Visual Slide 3: Mockup Daftar Chat Asli NoBox (Nama, Jam, Pin, Pesan Suara, Label & Funnel)
  Widget _buildChatListIllustration() {
    return Container(
      width: 295,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── TILE 1: Chat Pinned (Persis seperti layout chat_list_page.dart) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Foto Kontak
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: AppTheme.primaryColor, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                // Konten Chat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris 1: Nama Kontak + Jam & Ikon Pin Biru
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Juhri - SMKN 1 PASURUAN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '09:27',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.push_pin,
                            size: 13,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Baris 2: Last Message (Voice Note / Pesan Suara)
                      Row(
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 13,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '🎤 Pesan Suara (0:15)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Baris 3: Label & Funnel (Persis letak & ikonnya)
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'VIP, Reseller',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.filter_alt,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '✅ Lunas',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── TILE 2: Chat Kedua dengan Pesan Baru & Badge Unread ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'BS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Konten Chat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris 1: Nama & Jam
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Budi Santoso',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '08:45',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Baris 2: Pesan Baru & Badge Unread
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Halo kak, produk ini ready?',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Baris 3: Label & Funnel
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Prospek Baru',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.filter_alt,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Follow Up',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum IllustrationType {
  channels,
  multimedia,
  organization,
}

class OnboardingItem {
  final String badge;
  final String title;
  final String description;
  final IllustrationType illustrationType;

  const OnboardingItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.illustrationType,
  });
}
