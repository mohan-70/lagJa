// LoginScreen: Provides the first point of entry for users.
// Features a modern, minimal UI with Google OAuth integration for authentication.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/ui/gradient_button.dart';
import '../widgets/ui/ui_constants.dart';
import '../widgets/ui/shimmer_loader.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ─── State & Initialization ───

  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // ─── Build Method ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            // Decorative layer: Radial Gradient circle for a subtle background glow
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Top layer: Main Content (Logo, Tagline, Sign-in Button)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    // App Icon with rounded corners and optional loading shimmer
                    SizedBox(
                      width: 116,
                      height: 116,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isLoading)
                            const ShimmerContainer(
                              width: 116,
                              height: 116,
                              borderRadius: 24,
                            ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset('assets/icons/app_icon.png',
                                width: 100, height: 100),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your placement journey starts here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                    ),
                    const Spacer(flex: 4),
                    // Dynamic button state: switches between GradientButton and Shimmer during login
                    _isLoading
                        ? const ShimmerContainer(
                            height: 56,
                            borderRadius: 16,
                          )
                        : GradientButton(
                            label: 'Continue with Google',
                            onTap: _handleGoogleSignIn,
                            icon: const Icon(Icons.g_mobiledata,
                                size: 24, color: Colors.white),
                          ),
                    const SizedBox(height: 48),
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

  // ─── Auth Logic ───

  /// Triggers the Google Sign-In flow using the AuthService
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        // Notifying user in case of authentication failure
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

