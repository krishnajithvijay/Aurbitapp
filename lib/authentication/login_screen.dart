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
  _LoginMode _loginMode = _LoginMode.password;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      if (mounted) {
        setState(() {
          _otpSent = true;
        });
      }
      _showSnack(
        'Check your email for a code or sign-in link.',
      );
    } on AuthException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Unable to send the email code.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    if (_loginMode == mode) {
      return;
    }

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
    if (!kIsWeb) {
      return null;
    }

    final base = Uri.base;
    return base.replace(
      queryParameters: <String, String>{},
      fragment: '',
    ).toString();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 800;
    return isDesktop ? _buildWebLayout(isDark) : _buildMobileLayout(isDark);
  }

  Widget _buildWebLayout(bool isDark) {
    final background = isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg;

    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1A0533), Color(0xFF0D0620)]
                      : const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 48,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              child: Text(
                                'A',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                ),
                              ),
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
                        'Use password, social sign-in, or a one-time email code to get back into your quiet space.',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.78),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ...const [
                        'No public follower counts',
                        'Mood-aware connections',
                        'Private by design',
                      ].map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(255, 255, 255, 0.12),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(24)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Text(
                                feature,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color:
                  isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 56,
                    vertical: 48,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
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

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _buildForm(isDark, isWeb: false),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, {required bool isWeb}) {
    final textColor =
        isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText;
    final subColor =
        isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext;
    final borderColor =
        isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder;
    final inputBg = isDark ? const Color(0xFF1F1F28) : const Color(0xFFF8F9FA);
    final dividerColor =
        isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder;

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
                onPressed: () => _showSnack(
                  'Write to krishnajithvijay@gmail.com',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isWeb) ...[
            Text(
              'Welcome back',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how you want to sign in.',
              style: GoogleFonts.inter(fontSize: 14, color: subColor),
            ),
            const SizedBox(height: 28),
          ] else ...[
            Text(
              'Welcome back',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to sign in.',
              style: GoogleFonts.inter(fontSize: 16, color: subColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
          ],
          _buildModeToggle(borderColor, inputBg, textColor),
          const SizedBox(height: 24),
          _label('Email', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            validator: (value) {
              if (!_isValidEmail(value ?? '')) {
                return 'Valid email required';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'aurbit@example.com',
              isDark: isDark,
              fill: inputBg,
              border: borderColor,
            ),
          ),
          const SizedBox(height: 20),
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
                hint: 'Password',
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        _showSnack(
                          'Use the email code option if you need a passwordless sign-in.',
                        );
                      },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Prefer a one-time code?',
                  style: GoogleFonts.inter(
                    color: AurbitWebTheme.accentPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              label: 'Sign In',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handlePasswordLogin,
            ),
          ] else ...[
            _label(_otpSent ? 'Email code' : 'Passwordless sign-in', subColor),
            const SizedBox(height: 8),
            if (_otpSent) ...[
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                style: GoogleFonts.inter(color: textColor, fontSize: 14),
                decoration: _inputDecoration(
                  hint: 'Enter the code from your email',
                  isDark: isDark,
                  fill: inputBg,
                  border: borderColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use the code from the email, or tap the email link and come back here.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: subColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _primaryButton(
                label: 'Verify Email Code',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _verifyEmailOtp,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _sendEmailOtp,
                child: Text(
                  'Resend code',
                  style: GoogleFonts.inter(
                    color: AurbitWebTheme.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(10),
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
                        'We will send a one-time code and sign-in link to this email.',
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
              const SizedBox(height: 16),
              _primaryButton(
                label: 'Send Email Code',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _sendEmailOtp,
              ),
            ],
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: Divider(color: dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: GoogleFonts.inter(color: subColor, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: dividerColor)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialButton(
                child: Image.asset(
                  'asset/google_logo.png',
                  height: 20,
                  width: 20,
                ),
                isDark: isDark,
                borderColor: borderColor,
                onTap: _isLoading
                    ? null
                    : () => _handleOAuth(OAuthProvider.google),
              ),
              const SizedBox(width: 16),
              _socialButton(
                child: FaIcon(
                  FontAwesomeIcons.apple,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
                isDark: isDark,
                borderColor: borderColor,
                onTap:
                    _isLoading ? null : () => _handleOAuth(OAuthProvider.apple),
              ),
            ],
          ),
          const SizedBox(height: 32),
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
                    MaterialPageRoute(
                      builder: (_) => const SignupScreen(),
                    ),
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

  Widget _buildModeToggle(
    Color borderColor,
    Color inputBg,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
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
      duration: const Duration(milliseconds: 180),
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
                color: selected ? Colors.white : textColor.withOpacity(0.78),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AurbitWebTheme.accentPrimary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AurbitWebTheme.accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _socialButton({
    required Widget child,
    required bool isDark,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 64,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F28) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
