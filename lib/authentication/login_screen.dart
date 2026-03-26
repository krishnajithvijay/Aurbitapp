import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fcm_service.dart';
import '../web/aurbit_web_theme.dart';
import 'signup_screen.dart';

enum _LoginMode { password, emailOtp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _otpSent = false;
  bool _rememberMe = false;
  _LoginMode _loginMode = _LoginMode.password;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ───────────────────── AUTH HANDLERS ─────────────────────

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      await _initializeFcm();
    } on AuthException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Unable to sign in right now.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmailOtp() async {
    if (!_isValidEmail(_emailCtrl.text)) {
      _showSnack('Enter a valid email address first.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailCtrl.text.trim(),
        emailRedirectTo: _webRedirectTo,
      );
      if (mounted) setState(() => _otpSent = true);
      _showSnack('Check your email for a code or sign-in link.');
    } on AuthException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Unable to send the email code.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    if (!_isValidEmail(_emailCtrl.text)) {
      _showSnack('Enter a valid email address first.', isError: true);
      return;
    }
    if (_otpCtrl.text.trim().length < 6) {
      _showSnack('Enter the code from your email.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailCtrl.text.trim(),
        token: _otpCtrl.text.trim(),
        type: OtpType.email,
      );
      await _initializeFcm();
    } on AuthException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Unable to verify the email code.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOAuth(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      // On mobile, use a custom URL scheme so the browser redirects back to
      // the app after the user completes sign-in. On web, use the current URL.
      final redirectUrl = kIsWeb
          ? _webRedirectTo
          : 'com.example.aurbitapp://login-callback/';

      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectUrl,
        scopes: switch (provider) {
          OAuthProvider.apple => 'name email',
          OAuthProvider.google => 'email profile',
          _ => null,
        },
      );

      if (!launched) {
        _showSnack('Unable to start ${provider.name} sign-in.', isError: true);
      }
    } on AuthException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Unable to start social sign-in.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeFcm() async {
    try {
      final fcm = FcmService();
      await fcm.initialize();
      await fcm.saveToken();
    } catch (error) {
      debugPrint('FCM init skipped: $error');
    }
  }

  void _switchMode(_LoginMode mode) {
    if (_loginMode == mode) return;
    setState(() {
      _loginMode = mode;
      _otpSent = false;
      _otpCtrl.clear();
    });
  }

  bool _isValidEmail(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed.contains('@') && trimmed.contains('.');
  }

  String? get _webRedirectTo {
    if (!kIsWeb) return null;
    final base = Uri.base;
    return base
        .replace(queryParameters: <String, String>{}, fragment: '')
        .toString();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : AurbitWebTheme.natureGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ───────────────────── BUILD ─────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 800;
    return isDesktop ? _buildWebLayout(isDark) : _buildMobileLayout(isDark);
  }

  // ─────────────── WEB LAYOUT ───────────────

  Widget _buildWebLayout(bool isDark) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-bleed nature-inspired gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF1A2A1F), Color(0xFF0F1A14), Color(0xFF0D0D12)]
                    : const [
                        Color(0xFFA8D5A2), // soft green
                        Color(0xFFF5D5C8), // peach
                        Color(0xFFF7EDE2), // beige
                        Color(0xFFE8C9A0), // warm sand
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative organic shapes
          if (!isDark) ...[
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurbitWebTheme.natureGreen.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurbitWebTheme.natureTeal.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 80,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurbitWebTheme.naturePeach.withOpacity(0.3),
                ),
              ),
            ),
          ],

          // Hero text on the left
          Positioned(
            left: 60,
            top: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AurbitWebTheme.accentPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Aurbit',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AurbitWebTheme.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Centered tagline
          Positioned(
            left: 60,
            bottom: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your space.\nYour pace.',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : const Color(0xFF2D2D2D).withOpacity(0.2),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                ...['✦  Private by design', '✦  Mood-aware connections', '✦  No public follower counts']
                    .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : const Color(0xFF4A4A4A).withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ──── Glassmorphism Login Card ────
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 80),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: 420,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.45)
                              : Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: _buildForm(isDark, isWeb: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── MOBILE LAYOUT ───────────────

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2A1F), const Color(0xFF0D0D12)]
                : [
                    const Color(0xFFA8D5A2),
                    const Color(0xFFF5D5C8),
                    const Color(0xFFF7EDE2),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.4)
                          : Colors.white.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: _buildForm(isDark, isWeb: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────── FORM ───────────────

  Widget _buildForm(bool isDark, {required bool isWeb}) {
    final textColor = isDark ? AurbitWebTheme.darkText : const Color(0xFF1A1A2E);
    final subColor = isDark ? AurbitWebTheme.darkSubtext : const Color(0xFF6B7280);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFFE5E7EB);
    final inputBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.9);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ──
          Text(
            'Welcome 👋',
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 28 : 30,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: isWeb ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Login to access your Aurbit account',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: subColor,
              height: 1.5,
            ),
            textAlign: isWeb ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: 28),

          // ── Mode Toggle ──
          _buildModeToggle(borderColor, inputBg, textColor),
          const SizedBox(height: 24),

          // ── Email Field ──
          _label('Email', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            validator: (value) {
              if (!_isValidEmail(value ?? '')) return 'Valid email required';
              return null;
            },
            decoration: _inputDecoration(
              hint: 'mail@example.com',
              isDark: isDark,
              fill: inputBg,
              border: borderColor,
            ),
          ),
          const SizedBox(height: 20),

          // ── Password / OTP Section ──
          if (_loginMode == _LoginMode.password) ...[
            _label('Password', subColor),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              style: GoogleFonts.inter(color: textColor, fontSize: 14),
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Min 6 characters';
                }
                return null;
              },
              decoration: _inputDecoration(
                hint: '••••••••',
                isDark: isDark,
                fill: inputBg,
                border: borderColor,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: subColor,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),

            // ── Remember Me / Forgot Password ──
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: AurbitWebTheme.accentPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(color: borderColor, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Remember Me',
                  style: GoogleFonts.inter(fontSize: 13, color: subColor),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => _switchMode(_LoginMode.emailOtp),
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      color: AurbitWebTheme.accentPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Login Button ──
            _primaryButton(
              label: 'Login',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handlePasswordLogin,
            ),
          ] else ...[
            // ── OTP Flow ──
            _label(_otpSent ? 'Email code' : 'Passwordless sign-in', subColor),
            const SizedBox(height: 8),
            if (_otpSent) ...[
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                style: GoogleFonts.inter(color: textColor, fontSize: 14),
                decoration: _inputDecoration(
                  hint: 'Enter 6-digit code',
                  isDark: isDark,
                  fill: inputBg,
                  border: borderColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Check your email for the code or sign-in link.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: subColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _primaryButton(
                label: 'Verify Code',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _verifyEmailOtp,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _sendEmailOtp,
                  child: Text(
                    'Resend code',
                    style: GoogleFonts.inter(
                      color: AurbitWebTheme.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      color: AurbitWebTheme.accentPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We\'ll send a one-time code to your email.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _primaryButton(
                label: 'Send Email Code',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _sendEmailOtp,
              ),
            ],
          ],

          const SizedBox(height: 28),

          // ── Divider ──
          Row(
            children: [
              Expanded(child: Divider(color: borderColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or Sign in with',
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: borderColor)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Social Login Buttons ──
          _socialLoginButton(
            icon: Image.asset(
              'asset/google_logo.png',
              height: 20,
              width: 20,
              errorBuilder: (_, __, ___) => Text(
                'G',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4285F4),
                ),
              ),
            ),
            label: 'Continue with Google',
            isDark: isDark,
            borderColor: borderColor,
            onTap: _isLoading ? null : () => _handleOAuth(OAuthProvider.google),
          ),
          const SizedBox(height: 12),
          _socialLoginButton(
            icon: FaIcon(
              FontAwesomeIcons.apple,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
            label: 'Continue with Apple',
            isDark: isDark,
            borderColor: borderColor,
            onTap: _isLoading ? null : () => _handleOAuth(OAuthProvider.apple),
          ),

          const SizedBox(height: 28),

          // ── Sign Up ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.inter(color: subColor, fontSize: 13),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                child: Text(
                  'Sign up',
                  style: GoogleFonts.inter(
                    color: AurbitWebTheme.accentPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────── WIDGET HELPERS ───────────────

  Widget _buildModeToggle(Color borderColor, Color inputBg, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              label: 'Password',
              selected: _loginMode == _LoginMode.password,
              textColor: textColor,
              onTap: () => _switchMode(_LoginMode.password),
            ),
          ),
          Expanded(
            child: _modeButton(
              label: 'Email OTP',
              selected: _loginMode == _LoginMode.emailOtp,
              textColor: textColor,
              onTap: () => _switchMode(_LoginMode.emailOtp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? AurbitWebTheme.accentPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : textColor.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    required Color fill,
    required Color border,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: isDark ? Colors.grey[600] : Colors.grey[400],
        fontSize: 14,
      ),
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AurbitWebTheme.accentPrimary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AurbitWebTheme.accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _socialLoginButton({
    required Widget icon,
    required String label,
    required bool isDark,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
