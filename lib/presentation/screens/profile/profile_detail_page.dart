import 'package:flutter/material.dart';

class ProfileDetailPage extends StatelessWidget {
  final String title;
  final String content;

  const ProfileDetailPage({
    super.key,
    required this.title,
    required this.content,
  });

  Widget _buildRichText(String text, BuildContext context, bool isDark) {
    final List<TextSpan> spans = [];
    final parts = text.split('**');
    
    final baseStyle = TextStyle(
      color: isDark ? Colors.white70 : Colors.grey.shade700,
      fontSize: 16,
      height: 1.6,
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121B22) : Colors.grey[50],
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
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
          child: _buildRichText(content, context, isDark),
        ),
      ),
    );
  }
}
