import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'avatar_selection_screen.dart';
import '../services/fcm_service.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _emailCtrl        = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  final _usernameCtrl     = TextEditingController();

  String _selectedGender  = 'Male';
  int    _selectedDay     = 1;
  String _selectedMonth   = 'Jan';
  int    _selectedYear    = 2000;
  bool   _agreedToTerms   = false;
  bool   _isLoading       = false;
  bool   _obscurePassword = true;

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomUsername();
  }

  void _generateRandomUsername() {
    const adj   = ['cosmic','stellar','lunar','solar','astral','calm','quiet','zen','happy','bright','silent','gentle','serene','vivid','mystic','wandering','drifting','glowing','floating','rising'];
    const nouns = ['orbit','star','moon','sky','cloud','nebula','pulsar','comet','planet','void','river','mountain','ocean','breeze','spark','traveler','dreamer','seeker','spirit','soul'];
    final rng   = Random();
    setState(() {
      _usernameCtrl.text = '${adj[rng.nextInt(adj.length)]}_${nouns[rng.nextInt(nouns.length)]}_${rng.nextInt(9999)}';
    });
  }

  int _daysInMonth(String month, int year) {
    if (['Apr','Jun','Sep','Nov'].contains(month)) return 30;
    if (month == 'Feb') { final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0; return leap ? 29 : 28; }
    return 31;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please agree to the community guidelines')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        data: {
          'username': _usernameCtrl.text,
          'gender': _selectedGender,
          'birth_date': '$_selectedYear-${_months.indexOf(_selectedMonth) + 1}-$_selectedDay',
        },
      );
      if (mounted && res.user != null) {
        try { await FcmService().initialize(); await FcmService().saveToken(); } catch (_) {}
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AvatarSelectionScreen()));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An unexpected error occurred'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 800;
    return isDesktop ? _buildWebLayout(isDark) : _buildMobileLayout(isDark);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEB LAYOUT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWebLayout(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg,
      body: Row(
        children: [
          // ── Left brand panel ────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A0533), const Color(0xFF0D0620)]
                      : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Center(child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24))),
                          ),
                          const SizedBox(width: 12),
                          Text('Aurbit', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text('Join a calmer internet.', style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Create your account and discover\nconnections that actually matter.',
                        style: GoogleFonts.inter(fontSize: 15, color: Colors.white.withOpacity(0.7), height: 1.7),
                      ),
                      const SizedBox(height: 40),
                      ...[
                        ('✨', 'Mood-aware feed'),
                        ('🔒', 'Private by design'),
                        ('🛸', 'Orbit-based circles'),
                      ].map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(f.$1, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(f.$2, style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right form panel ─────────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              color: isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: _buildForm(isDark, isWeb: true),
                    ),
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
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildForm(isDark, isWeb: false),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED FORM
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildForm(bool isDark, {required bool isWeb}) {
    final textColor   = isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText;
    final subColor    = isDark ? AurbitWebTheme.darkSubtext  : AurbitWebTheme.lightSubtext;
    final borderColor = isDark ? AurbitWebTheme.darkBorder   : AurbitWebTheme.lightBorder;
    final inputBg     = isDark ? const Color(0xFF1F1F28)     : const Color(0xFFF8F9FA);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row (mobile only)
          if (!isWeb) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor)),
                  child: IconButton(icon: Icon(Icons.help_outline, size: 20, color: subColor), onPressed: () {}),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, size: 18, color: subColor),
                  label: Text('Back', style: GoogleFonts.inter(color: subColor, fontSize: 16)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (isWeb) ...[
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: subColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Back to sign in', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 28),
          ],

          // Title
          Text(
            'Create your Aurbit',
            style: GoogleFonts.inter(
              fontSize: isWeb ? 28 : 32,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.1,
            ),
            textAlign: isWeb ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Join a calmer corner of the internet',
            style: GoogleFonts.inter(fontSize: isWeb ? 14 : 16, color: subColor),
            textAlign: isWeb ? TextAlign.left : TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Email
          _label('Email address', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Valid email required' : null,
            decoration: _inputDeco('aurbit@example.com', isDark, inputBg, borderColor),
          ),

          const SizedBox(height: 16),

          // Password
          _label('Password', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
            decoration: _inputDeco('Create a password', isDark, inputBg, borderColor).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: subColor, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Username
          _label('Your username', subColor),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameCtrl,
            readOnly: true,
            style: GoogleFonts.inter(color: textColor, fontSize: 14),
            decoration: _inputDeco('username', isDark, inputBg, borderColor).copyWith(
              suffixIcon: Tooltip(
                message: 'Generate new username',
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: AurbitWebTheme.accentPrimary, size: 18),
                  onPressed: _generateRandomUsername,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Gender
          _label('Gender', subColor),
          const SizedBox(height: 8),
          Row(
            children: ['Male', 'Female', 'Other'].map((g) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: g != 'Other' ? 10 : 0),
                child: _genderBtn(g, isDark, borderColor, inputBg, textColor),
              ),
            )).toList(),
          ),

          const SizedBox(height: 16),

          // Date of birth
          _label('Date of birth', subColor),
          const SizedBox(height: 8),
          Row(
            children: [
              // Day
              Expanded(
                flex: 2,
                child: _dropdownBox(isDark, inputBg, borderColor,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDay,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1F1F28) : Colors.white,
                      style: GoogleFonts.inter(color: textColor, fontSize: 14),
                      items: List.generate(_daysInMonth(_selectedMonth, _selectedYear), (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDay = v!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Month
              Expanded(
                flex: 3,
                child: _dropdownBox(isDark, inputBg, borderColor,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1F1F28) : Colors.white,
                      style: GoogleFonts.inter(color: textColor, fontSize: 14),
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedMonth = v!;
                          if (_selectedDay > _daysInMonth(_selectedMonth, _selectedYear)) _selectedDay = 1;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Year
              Expanded(
                flex: 3,
                child: _dropdownBox(isDark, inputBg, borderColor,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1F1F28) : Colors.white,
                      style: GoogleFonts.inter(color: textColor, fontSize: 14),
                      items: List.generate(100, (i) => DateTime.now().year - i - 13)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedYear = v!;
                          if (_selectedDay > _daysInMonth(_selectedMonth, _selectedYear)) _selectedDay = 1;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Terms checkbox
          GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: _agreedToTerms ? AurbitWebTheme.accentPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _agreedToTerms ? AurbitWebTheme.accentPrimary : borderColor,
                      width: 1.5,
                    ),
                  ),
                  child: _agreedToTerms
                      ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "By signing up, you're joining a mindful space free from likes, follower counts, and algorithmic pressure.",
                    style: GoogleFonts.inter(fontSize: 12, color: subColor, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Create account button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AurbitWebTheme.accentPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Create Account', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 20),

          // Sign in link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Sign in',
                  style: GoogleFonts.inter(color: AurbitWebTheme.accentPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
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
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AurbitWebTheme.accentPrimary, width: 2)),
    errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 2)),
  );

  Widget _genderBtn(String gender, bool isDark, Color borderColor, Color inputBg, Color textColor) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AurbitWebTheme.accentPrimary.withOpacity(0.1) : inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AurbitWebTheme.accentPrimary : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          gender,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AurbitWebTheme.accentPrimary : textColor,
          ),
        ),
      ),
    );
  }

  Widget _dropdownBox(bool isDark, Color fill, Color border, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
