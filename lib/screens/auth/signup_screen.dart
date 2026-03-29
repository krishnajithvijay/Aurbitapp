import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        username: _usernameCtrl.text.trim().toLowerCase(),
        displayName: _displayNameCtrl.text.trim(),
      );
      if (!mounted) return;
      if (user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String e) {
    if (e.contains('already registered')) return 'Email already in use';
    if (e.contains('username')) return 'Username taken';
    if (e.contains('network')) return 'Check your internet connection';
    return 'Sign up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Aurbit 🚀',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  'Create your account to get started',
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate(delay: 100.ms).fadeIn(),
                const SizedBox(height: 36),
                AppTextField(
                  controller: _displayNameCtrl,
                  label: 'Display Name',
                  hint: 'Your name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _usernameCtrl,
                  label: 'Username',
                  hint: 'yourhandle',
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 3) return 'Minimum 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                      return 'Only letters, numbers, underscores';
                    }
                    return null;
                  },
                ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ).animate(delay: 360.ms).fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscure,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ).animate(delay: 440.ms).fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Confirm Password',
                  hint: '••••••••',
                  obscureText: _obscure,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ).animate(delay: 520.ms).fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),
                Text(
                  '🔒 Your messages are E2E encrypted. Your private key never leaves your device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentGreen,
                      ),
                ).animate(delay: 600.ms).fadeIn(),
                const SizedBox(height: 28),
                AppButton(
                  text: 'Create Account',
                  isLoading: _loading,
                  onPressed: _signup,
                  gradient: AppColors.primaryGradient,
                ).animate(delay: 680.ms).fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
