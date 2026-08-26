import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    final email = authProvider.currentUser ?? 'User';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil NoBox.ai'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF121B22) : Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with gradient background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 60),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2C3940), const Color(0xFF1F2C34)]
                      : [Colors.blue, Colors.blue.shade800],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF1F2C34) : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'NoBox.AI User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Info Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Akun',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInfoCard(
                    isDark,
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: email,
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    isDark,
                    icon: Icons.business_outlined,
                    title: 'Total Akun Terhubung',
                    value: '${chatProvider.cachedAccounts?.length ?? 0} Akun',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // About NoBox AI Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang NoBox AI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        _AccordionList(isDark: isDark),
                        const SizedBox(height: 24),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final Uri url = Uri.parse('https://docs.nobox.ai/id/docs');
                              if (!await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              )) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tidak dapat membuka tautan.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.language, size: 18),
                            label: const Text(
                              'Baca Dokumentasi Resmi NoBox.AI',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.blue.shade300
                                  : Colors.blue,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.blue.withOpacity(0.3)
                                    : Colors.blue.shade200,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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
              child: Column(
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
                    'Versi 1.0.0',
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.blue.shade300 : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class _AccordionList extends StatefulWidget {
  final bool isDark;
  const _AccordionList({required this.isDark});

  @override
  State<_AccordionList> createState() => _AccordionListState();
}

class _AccordionListState extends State<_AccordionList> {
  final List<GlobalKey> _keys = List.generate(4, (index) => GlobalKey());
  final List<ExpansionTileController> _controllers = List.generate(4, (index) => ExpansionTileController());

  Widget _buildExpandableSection(
    int index, {
    required String title,
    required String content,
  }) {
    final bool isInitiallyExpanded = false;
    return Material(
      key: _keys[index],
      color: widget.isDark ? const Color(0xFF2C3940) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: _controllers[index],
          initiallyExpanded: isInitiallyExpanded,
          onExpansionChanged: (expanded) {
            if (expanded) {
              // Collapse other tiles smoothly
              for (int i = 0; i < 4; i++) {
                if (i != index && _controllers[i].isExpanded) {
                  _controllers[i].collapse();
                }
              }
              // Auto scroll to the expanded item after a short delay to allow animation
              Future.delayed(const Duration(milliseconds: 200), () {
                if (_keys[index].currentContext != null) {
                  Scrollable.ensureVisible(
                    _keys[index].currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: 0.1, // Sedikit jarak dari atas layar
                  );
                }
              });
            }
          },
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          iconColor: widget.isDark ? Colors.blue.shade300 : Colors.blue,
          collapsedIconColor: widget.isDark
              ? Colors.white54
              : Colors.grey.shade600,
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          children: [
            Text(
              content,
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSection(
          0,
          title: 'Tentang NoBox.AI',
          content:
              'NoBox.AI adalah platform berbasis kecerdasan buatan yang dirancang untuk mengintegrasikan layanan komunikasi, pemasaran, dan customer service dalam satu sistem terpusat. Platform ini membantu bisnis mengelola interaksi pelanggan secara otomatis, terstruktur, dan efisien.\n\nNoBox.AI mendukung berbagai kanal komunikasi, seperti WhatsApp, Telegram, website, media sosial, dan marketplace, sehingga seluruh pesan pelanggan dapat dikelola dalam satu dashboard. Dengan teknologi AI yang human-like, sistem mampu memberikan respon yang cepat, relevan, dan konsisten.\n\nSelain itu, NoBox.AI dilengkapi dengan fitur Automasi, AI Agent, Human Agent, serta sistem monitoring dan pelaporan. Fitur-fitur ini memungkinkan perusahaan memantau kinerja layanan, mengelola tim, dan menganalisis data interaksi pelanggan secara menyeluruh.',
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          1,
          title: 'Mengapa NoBox.AI?',
          content:
              'NoBox.AI membantu bisnis meningkatkan kualitas layanan pelanggan tanpa harus menambah beban kerja secara manual. Dengan sistem otomatis, perusahaan dapat merespons pelanggan lebih cepat dan lebih akurat.',
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          2,
          title: 'Keunggulan Utama',
          content:
              '• Menghemat waktu dan biaya operasional melalui automasi layanan.\n• Meningkatkan kepuasan pelanggan dengan respon yang cepat dan konsisten.\n• Memudahkan pengelolaan komunikasi dari berbagai platform dalam satu sistem.\n• Mendukung pengambilan keputusan berbasis data melalui fitur laporan dan monitoring.\n• Fleksibel dan dapat disesuaikan dengan kebutuhan bisnis.\n\nDengan keunggulan tersebut, NoBox.AI menjadi solusi yang tepat bagi UMKM hingga perusahaan besar untuk membangun layanan pelanggan yang profesional, modern, dan berkelanjutan.',
        ),
        const SizedBox(height: 12),
        _buildExpandableSection(
          3,
          title: 'Target Pengguna',
          content:
              'NoBox.AI dirancang untuk membantu berbagai jenis organisasi dan pelaku usaha dalam mengelola komunikasi dan layanan pelanggan secara lebih efektif:\n\n• UMKM: Mengelola pesan, promosi, dan layanan otomatis tanpa tim besar.\n• Perusahaan Menengah & Besar: Mendukung operasional CS kompleks dengan sistem terintegrasi dan pelaporan.\n• Startup Digital: Membangun sistem layanan pelanggan modern berbasis AI.\n• Lembaga Pendidikan: Melayani pertanyaan siswa dan orang tua lintas kanal.\n• Instansi Pemerintah: Mendukung pelayanan masyarakat yang responsif dan transparan.\n• E-Commerce & Marketplace: Pengelolaan pesanan dan komplain secara otomatis dan terpusat.',
        ),
      ],
    );
  }
}
