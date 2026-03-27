import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fcm_service.dart';
import 'signup_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────

const _kBg = Color(0xFF0A0A0A);
const _kPurple = Color(0xFF7C3AED);
const _kIndigo = Color(0xFF6366F1);
const _kText = Colors.white;
const _kSubtext = Color(0xFF9CA3AF);
const _kGlassBorder = Color(0x1AFFFFFF); // white 10%
const _kGlassBg = Color(0x33000000);    // black 20%

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Form
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Background animation
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _bgAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ───────────────── AUTH ─────────────────

  String? get _webRedirectTo {
    if (!kIsWeb) return null;
    return Uri.base
        .replace(queryParameters: <String, String>{}, fragment: '')
        .toString();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter your email and password.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _initializeFcm();
    } on AuthException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? _webRedirectTo
            : 'com.example.aurbitapp://login-callback/',
        scopes: 'email profile',
      );
      if (!launched) {
        _showSnack('Unable to start Google sign-in.', isError: true);
      }
    } on AuthException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb
            ? _webRedirectTo
            : 'com.example.aurbitapp://login-callback/',
      );
      if (!launched) {
        _showSnack('Unable to start Apple sign-in.', isError: true);
      }
    } on AuthException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email address first, then tap Forgot?', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      _showSnack('Password reset email sent – check your inbox.');
    } on AuthException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeFcm() async {
    try {
      final fcm = FcmService();
      await fcm.initialize();
      await fcm.saveToken();
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : _kPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ───────────────── BUILD ─────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Animated gradient background orbs
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              painter: _NeonOrbsPainter(_bgAnim.value),
              child: const SizedBox.expand(),
            ),
          ),

          // Content
          SafeArea(
            child: isDesktop
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  // ───────────────── DESKTOP (two-column) ─────────────────

  Widget _buildDesktopLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: _kGlassBg,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: _kGlassBorder),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left branding panel
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(64),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            border: const Border(
                              right: BorderSide(color: _kGlassBorder),
                            ),
                          ),
                          child: _buildBrandingContent(isDesktop: true),
                        ),
                      ),
                      // Right form panel
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 72, vertical: 64),
                          color: Colors.black.withOpacity(0.25),
                          child: Center(child: _buildFormContent()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────── MOBILE (stacked) ─────────────────

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: _kGlassBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _kGlassBorder),
            ),
            child: Column(
              children: [
                // Top branding panel
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    border: const Border(
                      bottom: BorderSide(color: _kGlassBorder),
                    ),
                  ),
                  child: _buildBrandingContent(isDesktop: false),
                ),
                // Form panel
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: _buildFormContent(),
                ),
                // Mobile footer
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 32),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _kGlassBorder)),
                    color: Color(0x0D000000),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _footerLink('HELP'),
                      const SizedBox(width: 32),
                      _footerLink('RULES'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────── BRANDING CONTENT ─────────────────

  Widget _buildBrandingContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGlassBorder),
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 32 : 20),

            // Tagline
            Text(
              'Your space.\nYour pace.',
              style: GoogleFonts.poppins(
                fontSize: isDesktop ? 60 : 36,
                fontWeight: FontWeight.w800,
                color: _kText,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Rediscover digital intimacy in an\nenvironment built for presence,\nnot performance.',
              style: GoogleFonts.inter(
                fontSize: isDesktop ? 16 : 14,
                color: _kSubtext,
                height: 1.7,
              ),
            ),
            SizedBox(height: isDesktop ? 32 : 20),

            // Feature badges
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _featureBadge(Icons.center_focus_strong_outlined, 'Mindful Focus'),
                _featureBadge(Icons.menu_book_outlined, 'Journal'),
                _featureBadge(Icons.people_outline, 'Circles'),
              ],
            ),
          ],
        ),

        if (isDesktop) ...[
          const SizedBox(height: 48),
          Row(
            children: [
              _footerLink('HELP'),
              const SizedBox(width: 32),
              _footerLink('RULES'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _featureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _kGlassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kIndigo),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
        color: const Color(0xFF6B7280),
      ),
    );
  }

  // ───────────────── FORM CONTENT ─────────────────

  Widget _buildFormContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heading
          Text(
            'Welcome Aurbitor',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: _kText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to your quiet space',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _kSubtext,
            ),
          ),
          const SizedBox(height: 36),

          // Email field
          _fieldLabel('Email Address'),
          const SizedBox(height: 8),
          _inputField(
            controller: _emailCtrl,
            hint: 'name@sanctuary.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          // Password field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fieldLabel('Password'),
              GestureDetector(
                onTap: _isLoading ? null : _forgotPassword,
                child: Text(
                  'Forgot?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kIndigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _inputField(
            controller: _passwordCtrl,
            hint: 'Enter your password',
            obscure: _obscurePassword,
            suffixIcon: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Sign in button
          _signInButton(),
          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              const Expanded(child: Divider(color: _kGlassBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR CONTINUE WITH',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: _kGlassBorder)),
            ],
          ),
          const SizedBox(height: 20),

          // OAuth buttons
          LayoutBuilder(
            builder: (ctx, constraints) {
              final twoCol = constraints.maxWidth > 320;
              if (twoCol) {
                return Row(
                  children: [
                    Expanded(child: _oauthButton('Google', _googleIcon(), _signInWithGoogle)),
                    const SizedBox(width: 12),
                    Expanded(child: _oauthButton('Apple', _appleIcon(), _signInWithApple)),
                  ],
                );
              }
              return Column(
                children: [
                  _oauthButton('Google', _googleIcon(), _signInWithGoogle),
                  const SizedBox(height: 12),
                  _oauthButton('Apple', _appleIcon(), _signInWithApple),
                ],
              );
            },
          ),
          const SizedBox(height: 36),

          // Sign up link
          Center(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 14, color: _kSubtext),
                children: [
                  const TextSpan(text: 'New to Aurbit? '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      ),
                      child: Text(
                        'Create an account',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kIndigo,
                          decoration: TextDecoration.underline,
                          decorationColor: _kIndigo,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── FORM HELPERS ─────────────────

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF3F4F6),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: _kText, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: const Color(0xFF4B5563), fontSize: 15),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kGlassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kGlassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kPurple, width: 1.5),
        ),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(),
      ),
    );
  }

  Widget _signInButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPurple, _kIndigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _signInWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  'Sign in',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _oauthButton(String label, Widget icon, VoidCallback onTap) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: _kPurple.withOpacity(0.08),
          side: BorderSide(color: _kPurple.withOpacity(0.25)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }

  Widget _appleIcon() {
    return const Icon(Icons.apple, size: 22, color: _kText);
  }
}

// ───────────────── BACKGROUND PAINTER ─────────────────

class _NeonOrbsPainter extends CustomPainter {
  final double t;
  _NeonOrbsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Orb 1 – purple top-right
    _drawOrb(
      canvas,
      center: Offset(
        w * 0.75 + math.sin(t * math.pi) * 40,
        h * 0.2 + math.cos(t * math.pi) * 30,
      ),
      radius: math.min(w, h) * 0.35,
      color: const Color(0xFF7C3AED).withOpacity(0.18),
    );

    // Orb 2 – indigo bottom-left
    _drawOrb(
      canvas,
      center: Offset(
        w * 0.15 + math.cos(t * math.pi) * 35,
        h * 0.75 + math.sin(t * math.pi) * 25,
      ),
      radius: math.min(w, h) * 0.28,
      color: const Color(0xFF6366F1).withOpacity(0.15),
    );

    // Orb 3 – pink top-left accent
    _drawOrb(
      canvas,
      center: Offset(
        w * 0.1 + math.sin(t * math.pi * 1.3) * 20,
        h * 0.15 + math.cos(t * math.pi * 0.8) * 20,
      ),
      radius: math.min(w, h) * 0.18,
      color: const Color(0xFFF967FB).withOpacity(0.10),
    );
  }

  void _drawOrb(Canvas canvas,
      {required Offset center, required double radius, required Color color}) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_NeonOrbsPainter old) => old.t != t;
}
