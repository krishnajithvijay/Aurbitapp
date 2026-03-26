import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import '../main screens/main_screen.dart';
import '../services/fcm_service.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (mounted) {
        try {
          final fcm = FcmService();
          await fcm.initialize();
          await fcm.saveToken();
        } catch (e) {
          debugPrint('FCM error: $e');
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (r) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 800;
    return isDesktop ? _buildWebLayout(isDark) : _buildMobileLayout(isDark);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEB LAYOUT — Two-panel (brand left | form right)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWebLayout(bool isDark) {
    final bg = isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg;

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // ── Left brand panel ──────────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A0533), const Color(0xFF0D0620)]
                      : [const Color(0xFF7C3AED), const Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Aurbit',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Your space.\nYour pace.',
                        style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'A mindful social space free from\nlikes, follower counts, and\nalgorithmic pressure.',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.75),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Feature pills
                      ...[
                        ('🔒', 'No public follower counts'),
                        ('💜', 'Mood-aware connections'),
                        ('🌙', 'Private by design'),
                      ].map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(f.$1, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Text(
                                    f.$2,
                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right form panel ──────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              color: isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _buildForm(isDark, isWeb: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (unchanged feel)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(bool isDark) {
    final bg = isDark ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _buildForm(isDark, isWeb: false),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED FORM
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildForm(bool isDark, {required bool isWeb}) {
    final textColor    = isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText;
    final subColor     = isDark ? AurbitWebTheme.darkSubtext  : AurbitWebTheme.lightSubtext;
    final borderColor  = isDark ? AurbitWebTheme.darkBorder   : AurbitWebTheme.lightBorder;
    final inputBg      = isDark ? const Color(0xFF1F1F28) : const Color(0xFFF8F9FA);
    final dividerColor = isDark ? AurbitWebTheme.darkBorder   : AurbitWebTheme.lightBorder;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWeb) ...[
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.support_agent, color: subColor),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Write to krishnajithvijay@gmail.com')),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Heading
          if (isWeb) ...[
            Text('Welcome back', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 6),
            Text('Sign in to your quiet space', style: GoogleFonts.inter(fontSize: 14, color: subColor)),
            const SizedBox(height: 36),
          ] else ...[
            Text('Welcome back', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Sign in to your quiet space', style: GoogleFonts.inter(fontSize: 16, color: subColor), textAlign: TextAlign.center),
            const SizedBox(height: 48),
          ],

          // Email
          _label('Email', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Valid email required' : null,
            decoration: _inputDeco('aurbit@example.com', isDark, inputBg, borderColor),
          ),

          const SizedBox(height: 20),

          // Password
          _label('Password', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
            decoration: _inputDeco('••••••••', isDark, inputBg, borderColor).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: subColor, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('Forgot password?', style: GoogleFonts.inter(color: AurbitWebTheme.accentPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),

          const SizedBox(height: 20),

          // Sign in button
          _primaryButton(
            label: 'Sign In',
            isLoading: _isLoading,
            isDark: isDark,
            onPressed: _isLoading ? null : _handleLogin,
          ),

          const SizedBox(height: 28),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or continue with', style: GoogleFonts.inter(color: subColor, fontSize: 12)),
              ),
              Expanded(child: Divider(color: dividerColor)),
            ],
          ),

          const SizedBox(height: 24),

          // Social buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialBtn(
                child: Image.asset('asset/google_logo.png', height: 20, width: 20),
                isDark: isDark,
                borderColor: borderColor,
                onTap: () {},
              ),
              const SizedBox(width: 16),
              _socialBtn(
                child: FaIcon(FontAwesomeIcons.apple, color: isDark ? Colors.white : Colors.black, size: 20),
                isDark: isDark,
                borderColor: borderColor,
                onTap: () {},
              ),
              const SizedBox(width: 16),
              _socialBtn(
                child: FaIcon(FontAwesomeIcons.phone, color: isDark ? Colors.white : Colors.black, size: 18),
                isDark: isDark,
                borderColor: borderColor,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Sign up link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ", style: GoogleFonts.inter(color: subColor, fontSize: 13)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: Text(
                  'Sign up',
                  style: GoogleFonts.inter(color: AurbitWebTheme.accentPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _label(String text, Color color) => Text(
    text,
    style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w600),
  );

  InputDecoration _inputDeco(String hint, bool isDark, Color fill, Color border) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AurbitWebTheme.accentPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 2)),
  );

  Widget _primaryButton({required String label, required bool isLoading, required bool isDark, VoidCallback? onPressed}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AurbitWebTheme.accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _socialBtn({required Widget child, required bool isDark, required Color borderColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F28) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Center(child: child),
      ),
    );
  }
}
