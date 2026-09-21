import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_routes.dart';

// =====================================================================
// FITUR: Welcome Screen (Onboarding Carousel 3 Slide)
// FILE: lib/presentation/screens/welcome/welcome_page.dart
// FUNGSI: Menampilkan perkenalan fitur utama NoBox Chat (Omnichannel, 
//         Multimedia Voice/Chat, AI & Produktivitas) bagi pengguna baru 
//         sebelum menuju halaman Login.
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
      badge: 'PRODUKTIVITAS & AI',
      title: 'Tingkatkan Efisiensi\nBisnis Anda',
      description:
          'Prioritaskan percakapan penting dengan fitur Pin Chat, catatan kontak agen, arsip tiket, dan dukungan AI Agent cerdas.',
      illustrationType: IllustrationType.productivity,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
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
                      Text(
                        'NoBox',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
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
                      foregroundColor: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
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
                              isDark,
                              size,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Badge Kategori
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
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
                        const SizedBox(height: 12),

                        // Judul Slide
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Deskripsi Singkat
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
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
                              : (isDark
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.grey.shade300),
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
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.grey.shade100,
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
  Widget _buildIllustration(
    IllustrationType type,
    bool isDark,
    Size screenSize,
  ) {
    switch (type) {
      case IllustrationType.channels:
        return _buildChannelsIllustration(isDark);
      case IllustrationType.multimedia:
        return _buildMultimediaIllustration(isDark);
      case IllustrationType.productivity:
        return _buildProductivityIllustration(isDark);
    }
  }

  /// Visual Slide 1: Logo Channels Omnichannel NoBox
  Widget _buildChannelsIllustration(bool isDark) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(isDark ? 0.25 : 0.12),
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
              color: isDark ? AppTheme.darkSurface : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
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
          _buildChannelPill('assets/wa.png', 'WhatsApp', const Offset(-85, -60), isDark),
          _buildChannelPill('assets/telegram.png', 'Telegram', const Offset(85, -55), isDark),
          _buildChannelPill('assets/instagram.png', 'Instagram', const Offset(-90, 45), isDark),
          _buildChannelPill('assets/tiktok.png', 'TikTok', const Offset(90, 40), isDark),
          _buildChannelPill('assets/Tokopedia.png', 'Tokopedia', const Offset(0, 95), isDark),
          _buildChannelPill('assets/shopee.png', 'Shopee', const Offset(0, -100), isDark),
        ],
      ),
    );
  }

  Widget _buildChannelPill(
    String assetPath,
    String label,
    Offset offset,
    bool isDark,
  ) {
    return Transform.translate(
      offset: offset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16253B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visual Slide 2: Real-Time Chat & Multimedia Mockup
  Widget _buildMultimediaIllustration(bool isDark) {
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final bubbleIn = isDark ? const Color(0xFF1E324E) : const Color(0xFFEFF6FF);
    const bubbleOut = AppTheme.primaryColor;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Message Bubble (Inbound)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleIn,
                borderRadius: const BorderRadius.only(
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
                      Text(
                        '0:15 / 0:45',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Agent Message Bubble (Outbound Voice Note / Reply)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleOut,
                borderRadius: const BorderRadius.only(
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
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
                const SizedBox(width: 8),
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
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '240 KB • Selesai Terkirim',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
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

  /// Visual Slide 3: AI Assistant & Productivity Dashboard
  Widget _buildProductivityIllustration(bool isDark) {
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pinned Chat Mockup Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pelanggan VIP NoBox',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                      Text(
                        'Pesan suara baru diterima • 09:42',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Smart AI Suggestion Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.15),
                  const Color(0xFFEC4899).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Agent Ready',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      Text(
                        'Otomatisasi balasan dan routing tiket ke agen',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AKTIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureBadge(Icons.sync_rounded, 'Real-Time Sync', isDark),
              _buildFeatureBadge(Icons.shield_outlined, 'Aman & Terenkripsi', isDark),
              _buildFeatureBadge(Icons.speed_rounded, 'Multi-Agen', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String title, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

enum IllustrationType {
  channels,
  multimedia,
  productivity,
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
