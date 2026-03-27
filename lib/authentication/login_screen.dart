import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fcm_service.dart';
import '../web/aurbit_web_theme.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ───────────────── GOOGLE AUTH ─────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final redirectUrl = kIsWeb
          ? _webRedirectTo
          : 'com.example.aurbitapp://login-callback/';

      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        scopes: 'email profile',
      );

      if (!launched) {
        _showSnack('Unable to start Google sign-in.', isError: true);
      }
    } on AuthException catch (error) {
      _showSnack(error.message, isError: true);
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
    } catch (error) {
      debugPrint('FCM init skipped: $error');
    }
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
        backgroundColor:
            isError ? Colors.red.shade400 : AurbitWebTheme.natureGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ───────────────── BUILD ─────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 800;
    return isDesktop ? _buildWebLayout(isDark) : _buildMobileLayout(isDark);
  }

  // ───────────────── WEB LAYOUT ─────────────────

  Widget _buildWebLayout(bool isDark) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full background gradient ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [
                        Color(0xFF1A2A1F),
                        Color(0xFF0F1A14),
                        Color(0xFF0D0D12)
                      ]
                    : const [
                        Color(0xFF8BC6A0), // fresh green
                        Color(0xFFF2CDB4), // warm peach
                        Color(0xFFF7EDE2), // light beige
                        Color(0xFFE8C9A0), // sand
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative circles ──
          if (!isDark) ...[
            Positioned(
              top: -100,
              right: -50,
              child: _circle(320, AurbitWebTheme.natureGreen.withOpacity(0.12)),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: _circle(380, AurbitWebTheme.natureTeal.withOpacity(0.10)),
            ),
            Positioned(
              top: 80,
              left: 60,
              child: _circle(200, AurbitWebTheme.naturePeach.withOpacity(0.25)),
            ),
            Positioned(
              bottom: 100,
              right: 350,
              child: _circle(120, const Color(0xFFD4E7C5).withOpacity(0.3)),
            ),
          ],

          // ── Logo + Branding (top-left) ──
          Positioned(
            left: 56,
            top: 44,
            child: _logo(isDark),
          ),

          // ── Tagline (bottom-left) ──
          Positioned(
            left: 56,
            bottom: 56,
            child: _tagline(isDark),
          ),

          // ── Glassmorphism Login Card (right-center) ──
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 72),
                  child: _glassCard(isDark, maxWidth: 400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── MOBILE LAYOUT ─────────────────

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2A1F), const Color(0xFF0D0D12)]
                : [
                    const Color(0xFF8BC6A0),
                    const Color(0xFFF2CDB4),
                    const Color(0xFFF7EDE2),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              _logo(isDark),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _glassCard(isDark, maxWidth: double.infinity),
              ),
              const SizedBox(height: 24),
              _taglineMobile(isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── GLASS CARD ─────────────────

  Widget _glassCard(bool isDark, {required double maxWidth}) {
    final textColor =
        isDark ? AurbitWebTheme.darkText : const Color(0xFF1A1A2E);
    final subColor =
        isDark ? AurbitWebTheme.darkSubtext : const Color(0xFF6B7280);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: maxWidth == double.infinity ? null : maxWidth,
          constraints: maxWidth == double.infinity
              ? null
              : BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Waving hand icon (replaces emoji) ──
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AurbitWebTheme.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.waving_hand_rounded,
                    size: 30,
                    color: AurbitWebTheme.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Welcome text ──
              Text(
                'Welcome to Aurbit',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your quiet space for mindful\ndigital connections',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: subColor,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── Google Sign-in Button ──
              _googleButton(isDark),
              const SizedBox(height: 16),

              // ── Divider ──
              Row(
                children: [
                  Expanded(
                    child: Divider(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFFE5E7EB)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'or',
                      style: GoogleFonts.inter(
                        color: subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFFE5E7EB)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Sign Up Button ──
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignupScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : AurbitWebTheme.accentPrimary.withOpacity(0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Create an account',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AurbitWebTheme.accentPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Terms text ──
              Text(
                'By continuing, you agree to Aurbit\'s\nTerms of Service and Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: subColor.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── GOOGLE BUTTON ─────────────────

  Widget _googleButton(bool isDark) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, child) {
          return ElevatedButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            style: ElevatedButton.styleFrom(
              backgroundColor: AurbitWebTheme.accentPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google icon
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'G',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4285F4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // ───────────────── HELPERS ─────────────────

  Widget _logo(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
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
                fontSize: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Aurbit',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AurbitWebTheme.accentPrimary,
          ),
        ),
      ],
    );
  }

  Widget _tagline(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your space.\nYour pace.',
          style: GoogleFonts.poppins(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: isDark
                ? Colors.white70
                : const Color(0xFF2D2D2D).withOpacity(0.18),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        ...['Private by design', 'Mood-aware connections', 'No follower counts']
            .map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14,
                    color: isDark
                        ? Colors.white38
                        : AurbitWebTheme.natureGreen.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFF4A4A4A).withOpacity(0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _taglineMobile(bool isDark) {
    return Column(
      children: [
        ...['Private by design', 'Mood-aware', 'No follower counts'].map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 12,
                    color: isDark
                        ? Colors.white30
                        : AurbitWebTheme.natureGreen.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white30 : const Color(0xFF4A4A4A).withOpacity(0.4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
