import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/services/signalr_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/utils/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    debugPrint('SplashPage: initState');
    _checkLogin();
  }

  void _checkLogin() async {
    try {
      debugPrint('SplashPage: Starting _checkLogin');
      final auth = context.read<AuthProvider>();
      final theme = context.read<ThemeProvider>();
      final chatSettings = context.read<ChatSettingsProvider>();
      
      // Load with a timeout to prevent hanging
      await Future.wait([
        auth.checkAuth(),
        theme.loadTheme(),
        chatSettings.loadSettings(),
      ]).timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('SplashPage: Initialization timed out');
        return [];
      });

      debugPrint('SplashPage: Initialized, waiting for delay');
      await Future.delayed(const Duration(seconds: 5));

      if (!mounted) return;

      debugPrint('SplashPage: Navigating to next screen');
      if (auth.isLoggedIn) {
        // Connect SignalR for real-time messaging
        // Connect SignalR after navigation (delayed to avoid crash)
        Future.delayed(const Duration(seconds: 2), () {
          try {
            debugPrint('SplashPage: Starting deferred SignalR connection...');
            SignalRService().connect();
          } catch (e) {
            debugPrint('SplashPage: SignalR connection error (non-fatal): $e');
          }
        });
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      debugPrint('SplashPage Error: $e');
      // Fallback navigation if something goes wrong
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SplashPage: build called');
    return Material(
      color: Colors.white,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // Logo
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/nobox2.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.chat_bubble_rounded,
                      size: 100,
                      color: Color(0xFF0084FF),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // App Name
              const Text(
                'NoBox Chat',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              const Text(
                'Ai Powered Chatbot',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black45,
                  letterSpacing: 0.1,
                ),
              ),
              const Spacer(flex: 2),
              // Loading Progress
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0084FF)),
                  backgroundColor: Color(0xFFF0F0F0),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black38,
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
