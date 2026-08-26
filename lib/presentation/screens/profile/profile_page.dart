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
                      ? [const Color(0xFF1F2C34), const Color(0xFF121B22)]
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'NoBox AI User',
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.purple.withOpacity(0.1) : Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                color: isDark ? Colors.purple.shade300 : Colors.purple,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Marketing & CS Automation',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NoBox AI adalah platform teknologi pintar karya PT Universal Big Data (UBIG) yang hadir untuk membantu bisnis mengotomatiskan interaksi pelanggan dan aktivitas pemasaran. Dengan NoBox AI, Anda dapat mengelola CRM, membalas pesan melalui chatbot cerdas, serta melakukan broadcast promosi lintas platform secara efisien selama 24/7.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final Uri url = Uri.parse('https://nobox.ai');
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tidak dapat membuka tautan.')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.language, size: 18),
                          label: const Text('Kunjungi nobox.ai'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.blue.shade300 : Colors.blue,
                            side: BorderSide(
                              color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                  Icon(
                    Icons.all_inclusive_rounded,
                    size: 40,
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

  Widget _buildInfoCard(bool isDark, {required IconData icon, required String title, required String value}) {
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
              color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
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
