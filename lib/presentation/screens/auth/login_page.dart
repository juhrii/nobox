import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nobox_chat_basic/core/utils/app_validator.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/signalr_service.dart';
import 'package:nobox_chat_basic/core/providers/theme_provider.dart';
import 'package:nobox_chat_basic/core/utils/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  void _loadRememberedEmail() async {
    final auth = context.read<AuthProvider>();
    final email = await auth.getRememberedEmail();
    if (email != null) {
      setState(() {
        _emailController.text = email;
        _rememberMe = true;
      });
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      
      final response = await auth.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!response.isError) {
        // Handle remember me
        if (_rememberMe) {
          await auth.saveRememberedEmail(_emailController.text);
        } else {
          await auth.saveRememberedEmail(null);
        }

        if (!mounted) return;
        // Start SignalR connection for real-time messaging
        SignalRService().connect();
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Login failed. Please check your credentials.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Theme Toggle at Top Right
            Positioned(
              top: 10,
              right: 10,
              child: Consumer<ThemeProvider>(
                builder: (_, themeProvider, __) {
                  return IconButton(
                    iconSize: 28,
                    onPressed: () => themeProvider.toggleTheme(!isDark),
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  );
                },
              ),
            ),
            
            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // Custom Logo
                      Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          'assets/icons/nobox2.png',
                          height: 140,
                          width: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.chat_bubble_rounded,
                              size: 100,
                              color: theme.colorScheme.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // App Branding
                      Text(
                        'NoBoxChat',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          fontSize: 40,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black45,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 56),
                      
                      // Username/Email Field
                      _buildLabel('Username', isDark),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: _buildInputDecoration(
                          hint: 'Enter your username',
                          icon: Icons.person_outline_rounded,
                          isDark: isDark,
                        ),
                        validator: AppValidator.validateEmail,
                      ),
                      const SizedBox(height: 24),
                      
                      // Password Field
                      _buildLabel('Password', isDark),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: _buildInputDecoration(
                          hint: 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: isDark ? Colors.white30 : Colors.black26,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: AppValidator.validatePassword,
                      ),
                      const SizedBox(height: 16),
                      
                      // Remember Me Checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (value) => setState(() => _rememberMe = value ?? false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Remember Email',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      
                      // Sign In Button
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) {
                          return SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0084FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: auth.isAuthenticating ? null : _login,
                              child: auth.isAuthenticating
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 64),
                      
                      // Footer
                      Text(
                        'Powered by Nobox',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white30 : Colors.black26,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 15,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
      prefixIcon: Icon(icon, color: isDark ? Colors.white30 : Colors.black26, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0084FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
