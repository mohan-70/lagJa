import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  static const _purple = Color(0xFF6C63FF);
  static const _bg = Color(0xFF000000);
  static const _card = Color(0xFF1C1C1E);
  static const _border = Color(0xFF2C2C2E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.rocket_launch_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text('Lagja', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700, letterSpacing: -1.5)),
                const SizedBox(height: 8),
                const Text('Your Placement Companion', style: TextStyle(color: _textSecondary, fontSize: 17, fontWeight: FontWeight.w400)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border, width: 0.5)),
                  child: Column(
                    children: [
                      _feature('DSA Tracker', Icons.code_rounded),
                      _divider(),
                      _feature('Application Manager', Icons.business_center_rounded),
                      _divider(),
                      _feature('Interview Notes', Icons.note_alt_rounded),
                      _divider(),
                      _feature('AI Roadmaps', Icons.map_rounded),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                _isLoading 
                    ? const CircularProgressIndicator(color: _purple) 
                    : SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _handleGoogleSignIn, child: const Text('Continue with Google'))),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(String text, IconData icon) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(icon, color: _purple, size: 22), const SizedBox(width: 16), Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))]));
  }

  Widget _divider() => const Divider(color: Color(0xFF38383A), height: 1, indent: 38);

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try { await _authService.signInWithGoogle(); } 
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); } 
    finally { if (mounted) setState(() => _isLoading = false); }
  }
}
