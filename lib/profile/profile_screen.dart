import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../authentication/login_screen.dart';
import '../widgets/verified_badge.dart';
import 'profile_settings_screen.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, dynamic>? _profile;
  int _postCount = 0;
  int _innerOrbitCount = 0;
  int _outerOrbitCount = 0;
  List<Map<String, dynamic>> _moodHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch Profile
      final profileRes = await _supabase
          .from('profiles')
          .select('*, is_verified')
          .eq('id', user.id)
          .single();

      // 2. Fetch Post Count
      int posts = 0;
      try {
        final countRes = await _supabase.from('posts').select('*').eq('user_id', user.id).count(CountOption.exact);
        posts = countRes.count;
      } catch (_) {}

      // 3. Inner/Outer Orbit Counts
      int inner = 0; 
      int outer = 0;
      try {
         final innerRes = await _supabase.from('user_orbits').select('*').eq('user_id', user.id).eq('orbit_type', 'inner').count(CountOption.exact);
         inner = innerRes.count;
         final outerRes = await _supabase.from('user_orbits').select('*').eq('user_id', user.id).eq('orbit_type', 'outer').count(CountOption.exact);
         outer = outerRes.count;
      } catch (_) {}

      // 4. Mood History (7 days)
      final moods = await _supabase
          .from('mood_logs')
          .select()
          .eq('user_id', user.id)
          .order('picked_at', ascending: false)
          .limit(7);

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _postCount = posts;
          _innerOrbitCount = inner;
          _outerOrbitCount = outer;
          _moodHistory = List<Map<String, dynamic>>.from(moods);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  String _getMoodEmoji(String mood) {
    switch (mood) {
      case 'Happy': return '😊';
      case 'Sad': return '😢';
      case 'Tired': return '😴';
      case 'Irritated': return '😤';
      case 'Lonely': return '☁️';
      case 'Bored': return '😐';
      case 'Peaceful': return '😌';
      case 'Grateful': return '🙏';
      default: return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb  = kIsWeb;
    final textColor   = isWeb ? (isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText)    : (isDark ? Colors.white : Colors.black);
    final secondaryText = isWeb ? (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext) : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
    final cardColor   = isWeb ? (isDark ? AurbitWebTheme.darkCard    : AurbitWebTheme.lightCard)    : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isWeb ? (isDark ? AurbitWebTheme.darkBorder  : AurbitWebTheme.lightBorder)  : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final accent      = AurbitWebTheme.accentPrimary;
    
    // Default values if loading
    final username = _profile?['username'] ?? 'User';
    final createdAt = _profile?['created_at'] != null 
        ? DateTime.parse(_profile!['created_at']) 
        : DateTime.now();
    final bio = _profile?['bio'] ?? 'No bio yet';
    final verified = _profile?['is_verified'] ?? false;
    final joinDate = DateFormat('MMM yyyy').format(createdAt);

    return Scaffold(
      backgroundColor: isWeb
          ? (isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg)
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor),
             onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
                );
             },
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: accent))
        : isWeb ? _buildWebLayout(context, isDark, textColor, secondaryText, cardColor, borderColor, accent, username, bio, joinDate, _postCount) : _buildMobileBody(accent, username, verified, bio, joinDate, _postCount, isDark, textColor, secondaryText, cardColor, borderColor),
    );
  }

  Widget _buildMobileBody(Color accent, String username, bool verified, String bio, String joinDate, int postCount, bool isDark, Color textColor, Color secondaryText, Color cardColor, Color borderColor) {
    return _isLoading 
        ? Center(child: CircularProgressIndicator(color: accent))
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildProfileHeader(username, verified, bio, joinDate, isDark, textColor, secondaryText),
              const SizedBox(height: 32),
              
              // Stats
              Row(
                children: [
                   _buildStatCard('Posts', postCount, isDark),
                   const SizedBox(width: 12),
                   _buildStatCard('Inner Orbit', _innerOrbitCount, isDark),
                   const SizedBox(width: 12),
                   _buildStatCard('Outer Orbit', _outerOrbitCount, isDark),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Mood History
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.show_chart, size: 20, color: secondaryText), // Mock icon
                    const SizedBox(width: 8),
                    Text(
                      'Recent Mood History',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: secondaryText, // Usually greyish in design
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_moodHistory.isEmpty)
                Container(
                   width: double.infinity,
                   padding: const EdgeInsets.all(24),
                   decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                   ),
                   child: Text(
                     "No mood logs yet.", 
                     textAlign: TextAlign.center,
                     style: GoogleFonts.inter(color: secondaryText),
                   ),
                )
              else
                ..._moodHistory.map((log) {
                  final date = DateTime.parse(log['picked_at']);
                  final dayStr = DateFormat('MMM d').format(date);
                  final mood = log['mood'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getMoodEmoji(mood),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mood,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              dayStr,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              
              const SizedBox(height: 32),
              
              // Edit Profile Button
              _editProfileBtn(isDark, textColor, borderColor, accent),
              
              const SizedBox(height: 16),
              
              // Sign Out Button
              _signOutBtn(),
              
              const SizedBox(height: 24),
            ],
          ),
        );
  }

  Widget _buildWebLayout(BuildContext context, bool isDark, Color textColor, Color secondaryText, Color cardColor, Color borderColor, Color accent, String username, String bio, String joinDate, int postCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Center)
        Expanded(
          flex: 7,
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 740), // Constrain center content
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(username, _profile?['is_verified'] ?? false, bio, joinDate, isDark, textColor, secondaryText),
                      const SizedBox(height: 40),
                      Text(
                        'Recent Mood History',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                      ),
                      const SizedBox(height: 20),
                      if (_moodHistory.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            "No mood logs yet.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: secondaryText),
                          ),
                        )
                      else
                        ..._moodHistory.map((log) {
                          final date = DateTime.parse(log['picked_at']);
                          final dayStr = DateFormat('MMM d').format(date);
                          final mood = log['mood'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _getMoodEmoji(mood),
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mood,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      dayStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Right Sidebar
        _buildRightSidebar(isDark, cardColor, borderColor, textColor, secondaryText, accent, username, bio, joinDate, postCount),
      ],
    );
  }

  Widget _buildRightSidebar(bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryText, Color accent, String username, String bio, String joinDate, int postCount) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor)),
        color: isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightSidebar,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sidebarInfoCard('About $username', bio, isDark, cardColor, borderColor, textColor, secondaryText),
            const SizedBox(height: 16),
            _sidebarStatsCard(isDark, cardColor, borderColor, textColor, secondaryText, postCount, _innerOrbitCount, _outerOrbitCount),
            const SizedBox(height: 24),
            _editProfileBtn(isDark, textColor, borderColor, accent),
            const SizedBox(height: 12),
            _signOutBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String username, bool verified, String bio, String joinDate, bool isDark, Color textColor, Color secondaryText) {
    return Column(
      children: [
        // Avatar Section
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: kIsWeb ? const LinearGradient(
                colors: [AurbitWebTheme.accentPrimary, Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              border: kIsWeb ? null : Border.all(color: Colors.grey[300]!, width: 1),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: _profile?['avatar_url'] != null
                  ? (_profile!['avatar_url'].toString().contains('.svg') || 
                     _profile!['avatar_url'].toString().contains('dicebear'))
                    ? SvgPicture.network(_profile!['avatar_url'], fit: BoxFit.cover)
                    : Image.network(_profile!['avatar_url'], fit: BoxFit.cover)
                  : const Icon(Icons.person, size: 50, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Name & Badge
        UsernameWithBadge(
          username: username,
          isVerified: verified,
          textStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          badgeSize: 20,
          badgeColor: const Color(0xFF1DA1F2),
        ),
        
        const SizedBox(height: 8),
        Text(
          bio,
          style: GoogleFonts.inter(fontSize: 14, color: secondaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: secondaryText),
            const SizedBox(width: 6),
            Text(
              'Member since $joinDate',
              style: GoogleFonts.inter(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sidebarInfoCard(String title, String content, bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.inter(fontSize: 13, color: secondaryText, height: 1.4)),
        ],
      ),
    );
  }

  Widget _sidebarStatsCard(bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryText, int postCount, int innerOrbitCount, int outerOrbitCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          _statRow('Total Posts', '$postCount', textColor, secondaryText),
          const Divider(height: 24),
          _statRow('Inner Orbit', '$innerOrbitCount', textColor, secondaryText),
          const Divider(height: 24),
          _statRow('Outer Orbit', '$outerOrbitCount', textColor, secondaryText),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color textColor, Color secondaryText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: secondaryText)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }

  Widget _editProfileBtn(bool isDark, Color textColor, Color borderColor, Color accent) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit Profile feature coming soon")));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: kIsWeb ? accent : Colors.transparent,
          foregroundColor: kIsWeb ? Colors.white : textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: kIsWeb ? BorderSide.none : BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _signOutBtn() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _handleSignOut,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: Colors.red,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 20),
            const SizedBox(width: 8),
            Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, bool isDark) {
    final isWeb = kIsWeb;
    final cardBg     = isWeb ? (isDark ? AurbitWebTheme.darkCard   : AurbitWebTheme.lightCard)   : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderCol  = isWeb ? (isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder) : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final textCol    = isWeb ? (isDark ? AurbitWebTheme.darkText   : AurbitWebTheme.lightText)   : (isDark ? Colors.white : Colors.black);
    final subCol     = isWeb ? (isDark ? AurbitWebTheme.darkSubtext: AurbitWebTheme.lightSubtext): (isDark ? Colors.grey[400]! : Colors.grey[500]!);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isWeb ? AurbitWebTheme.accentPrimary : textCol,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: subCol,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
