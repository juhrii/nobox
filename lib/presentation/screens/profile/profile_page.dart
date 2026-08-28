import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'profile_detail_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil NoBox.ai'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF121B22) : Colors.grey[50],
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Hero Section
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C3940), const Color(0xFF1F2C34)]
                        : [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/nobox2.png',
                        height: 50,
                        width: 50,
                      ),
                    ),
                    const SizedBox(height: 20),
                  const Text(
                    'NoBox.AI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-Powered Omnichannel Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

            const SizedBox(height: 30),

            // About NoBox AI Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang NoBox AI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileMenuList(isDark: isDark),
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final Uri url = Uri.parse('https://nobox.ai/');
                                if (!await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tidak dapat membuka tautan.'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Kunjungi Website NoBox.AI'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final Uri url = Uri.parse('https://docs.nobox.ai/id/docs');
                                if (!await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tidak dapat membuka tautan.'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.menu_book, size: 18),
                              label: const Text('Baca Dokumentasi Resmi'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue,
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.blue.shade200,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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

            const SizedBox(height: 40),

            // Footer App Version
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.hasData ? snapshot.data!.version : '1.0.0';
                  return Column(
                    children: [
                      Image.asset(
                        'assets/nobox2.png',
                        height: 40,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NoBox Chat App',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Versi $version',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuList extends StatelessWidget {
  final bool isDark;
  const _ProfileMenuList({required this.isDark});

  Widget _buildRichText(String text, BuildContext context, bool isDark) {
    final List<TextSpan> spans = [];
    final parts = text.split('**');
    
    final baseStyle = TextStyle(
      color: isDark ? Colors.white70 : Colors.grey.shade700,
      fontSize: 14,
      height: 1.5,
    );

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: baseStyle,
        ));
      }
    }
    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildMenuSection(
    BuildContext context,
    int index, {
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF2C3940) : Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            iconColor: isDark ? Colors.blue.shade300 : Colors.blue,
            collapsedIconColor: isDark ? Colors.blue.shade300 : Colors.blue,
            childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRichText(content, context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMenuSection(
          context,
          0,
          title: 'Tentang NoBox.AI',
          content:
              'NoBox.AI adalah platform berbasis kecerdasan buatan yang dirancang untuk mengintegrasikan layanan komunikasi, pemasaran, dan customer service dalam satu sistem terpusat. Platform ini membantu bisnis mengelola interaksi pelanggan secara otomatis, terstruktur, dan efisien.\n\nNoBox.AI mendukung berbagai kanal komunikasi, seperti WhatsApp, Telegram, website, media sosial, dan marketplace, sehingga seluruh pesan pelanggan dapat dikelola dalam satu dashboard. Dengan teknologi AI yang human-like, sistem mampu memberikan respon yang cepat, relevan, dan konsisten.\n\nSelain itu, NoBox.AI dilengkapi dengan fitur Automasi, AI Agent, Human Agent, serta sistem monitoring dan pelaporan. Fitur-fitur ini memungkinkan perusahaan memantau kinerja layanan, mengelola tim, dan menganalisis data interaksi pelanggan secara menyeluruh.',
        ),
        _buildMenuSection(
          context,
          1,
          title: 'Mengapa NoBox.AI?',
          content:
              'NoBox.AI membantu bisnis meningkatkan kualitas layanan pelanggan tanpa harus menambah beban kerja secara manual. Dengan sistem otomatis, perusahaan dapat merespons pelanggan lebih cepat dan lebih akurat.',
        ),
        _buildMenuSection(
          context,
          2,
          title: 'Keunggulan Utama',
          content:
              '• Menghemat waktu dan biaya operasional melalui automasi layanan.\n• Meningkatkan kepuasan pelanggan dengan respon yang cepat dan konsisten.\n• Memudahkan pengelolaan komunikasi dari berbagai platform dalam satu sistem.\n• Mendukung pengambilan keputusan berbasis data melalui fitur laporan dan monitoring.\n• Fleksibel dan dapat disesuaikan dengan kebutuhan bisnis.\n\nDengan keunggulan tersebut, NoBox.AI menjadi solusi yang tepat bagi UMKM hingga perusahaan besar untuk membangun layanan pelanggan yang profesional, modern, dan berkelanjutan.',
        ),
        _buildMenuSection(
          context,
          3,
          title: 'Target Pengguna',
          content:
              'NoBox.AI dirancang untuk membantu berbagai jenis organisasi dan pelaku usaha dalam mengelola komunikasi dan layanan pelanggan secara lebih efektif:\n\n• **UMKM:** Mengelola pesan, promosi, dan layanan otomatis tanpa tim besar.\n• **Perusahaan Menengah & Besar:** Mendukung operasional CS kompleks dengan sistem terintegrasi dan pelaporan.\n• **Startup Digital:** Membangun sistem layanan pelanggan modern berbasis AI.\n• **Lembaga Pendidikan:** Melayani pertanyaan siswa dan orang tua lintas kanal.\n• **Instansi Pemerintah:** Mendukung pelayanan masyarakat yang responsif dan transparan.\n• **E-Commerce & Marketplace:** Pengelolaan pesanan dan komplain secara otomatis dan terpusat.',
        ),
        _buildMenuSection(
          context,
          4,
          title: 'Gambaran Umum',
          content:
              'NoBox.AI adalah aplikasi kecerdasan buatan (AI) yang dirancang untuk meningkatkan kualitas layanan marketing dan customer service di instansi pendidikan, bisnis, dan pemerintahan. Platform ini membantu mengumpulkan, mengelola, dan menganalisis data pelanggan secara terintegrasi.\n\nDengan dukungan chatbot cerdas dan sistem omnichannel, NoBox.AI mampu menangani komunikasi pelanggan selama 24 jam nonstop sepanjang tahun, sehingga bisnis dapat memberikan layanan yang lebih cepat, konsisten, dan profesional.',
        ),
        _buildMenuSection(
          context,
          5,
          title: 'Modul Utama NoBox.AI',
          content:
              'NoBox.AI terdiri dari beberapa modul utama yang saling terintegrasi untuk mendukung operasional bisnis secara menyeluruh, mulai dari komunikasi pelanggan hingga pengelolaan sistem.\n\n• **Pesan:** Mengelola seluruh percakapan pelanggan dari berbagai kanal komunikasi.\n• **CRM:** Menyimpan dan mengelola data pelanggan, status prospek, dan aktivitas penjualan.\n• **Formulir:** Membuat formulir digital seperti pendaftaran dan survei pelanggan.\n• **Promosi:** Pengiriman pesan promosi dan campaign pemasaran secara terjadwal.\n• **Kontak:** Mengelola database pelanggan.\n• **Akun:** Mengatur data akun pengguna, lisensi, dan status layanan.\n• **AI Agents:** Mengelola chatbot berbasis AI sesuai skenario.\n• **Human Agents:** Mengatur agen manusia untuk percakapan lanjutan.\n• **Berlangganan:** Informasi paket layanan dan fitur yang tersedia.\n• **Billing:** Mengelola tagihan dan status transaksi.\n• **Pengaturan:** Mengatur sistem secara menyeluruh termasuk profil, file manager, dan integrasi.',
        ),
        _buildMenuSection(
          context,
          6,
          title: 'Detail Keunggulan',
          content:
              'NoBox.AI memiliki berbagai keunggulan yang mendukung kemudahan penggunaan, keamanan data, dan integrasi sistem.\n\n**Tampilan:**\n• **Menu Per Role User:** Tampilan menu disesuaikan dengan peran pengguna\n• **Tracking Data:** Memudahkan pemantauan aktivitas dan data sistem\n• **Tampilan Fleksibel:** Layout dapat disesuaikan dengan kebutuhan pengguna\n• **Pilihan Tema:** Tersedia tema terang dan gelap\n\n**Keamanan:**\n• **Hak Akses User:** Pengaturan hak akses berdasarkan role pengguna\n\n**Integrasi:**\n• **Import Kontak:** Mendukung file Excel dan CSV\n• **Export Kontak:** Mendukung format Google Contacts',
        ),
      ],
    );
  }
}
