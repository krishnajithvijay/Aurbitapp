import '../widgets/add_to_orbit_dialog.dart';
import '../space/post_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../web/aurbit_web_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/orbit_service.dart';
import '../services/mood_service.dart';
import '../models/mood_log.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialAvatarUrl;

  const UserProfileScreen({
    super.key, 
    required this.userId,
    this.initialAvatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  final _orbitService = OrbitService();
  final _supabase = Supabase.instance.client;
  
  Map<String, dynamic>? _profile;
  List<MoodLog> _moodHistory = [];
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _userComments = [];
  String? _orbitStatus; 
  bool _isPending = false;
  bool _isLoading = true;
  bool _isMe = false;
  int _postCount = 0;
  int _innerCount = 0;
  int _outerCount = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isMe = _supabase.auth.currentUser?.id == widget.userId;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Only show loading indicator if we don't have initial data to show
    if (_profile == null && widget.initialAvatarUrl == null) {
      setState(() => _isLoading = true);
    }
    
    // 1. Fetch Profile
    try {
       final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();
       if (mounted) {
         setState(() {
           _profile = profile;
         });
       }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }

    // 2. Fetch User Posts
    try {
      final postsRes = await _supabase
          .from('posts')
          .select('*, profiles (*)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      
      final commPostsRes = await _supabase
          .from('community_posts')
          .select('*, communities (username), profiles (*)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _userPosts = [
            ...(postsRes as List<dynamic>),
            ...(commPostsRes as List<dynamic>)
          ];
          _userPosts.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
        });
      }
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
    }

    // 3. Fetch User Comments
    try {
      final commentsRes = await _supabase
          .from('comments')
          .select('*, posts (*, profiles (*))')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _userComments = List<Map<String, dynamic>>.from(commentsRes as List<dynamic>);
        });
      }
    } catch (e) {
      debugPrint('Error fetching user comments: $e');
    }

    // 4. Fetch Mood History
    try {
      final history = await _orbitService.getUserMoodHistory(widget.userId);
      if (mounted) {
        setState(() {
          _moodHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Error fetching mood history: $e');
    }

    // 5. Status
    if (!_isMe) {
      try {
        final orbitType = await _orbitService.getOrbitType(widget.userId);
        bool isPending = false;
        if (orbitType == null) {
          isPending = await _orbitService.hasPendingOrbitRequest(widget.userId);
        }

        if (mounted) {
          setState(() {
            _orbitStatus = orbitType;
            _isPending = isPending;
          });
        }
      } catch (e) {
        debugPrint('Error fetching orbit status: $e');
      }
    }

    // 4. Fetch Orbit / Post Counts
    try {
      final postsCountRes = await _supabase.from('posts').select('id').eq('user_id', widget.userId);
      final commPostsCountRes = await _supabase.from('community_posts').select('id').eq('user_id', widget.userId);
      final innerCountRes = await _supabase.from('user_orbits').select('id').eq('user_id', widget.userId).eq('orbit_type', 'inner');
      final outerCountRes = await _supabase.from('user_orbits').select('id').eq('user_id', widget.userId).eq('orbit_type', 'outer');

      if (mounted) {
        setState(() {
          _postCount = (postsCountRes as List).length + (commPostsCountRes as List).length;
          _innerCount = (innerCountRes as List).length;
          _outerCount = (outerCountRes as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching counts: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _mapPost(Map<String, dynamic> raw) {
    final profile = raw['profiles'] ?? _profile ?? {};
    final isAnonymous = raw['is_anonymous'] == true;
    final createdAt = DateTime.parse(raw['created_at']);
    final diff = DateTime.now().difference(createdAt);
    
    String timeAgo;
    if (diff.inSeconds < 60) timeAgo = 'Just now';
    else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
    else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
    else timeAgo = '${diff.inDays}d ago';

    final community = raw['communities'];
    final Map<String, dynamic>? commMap = (community is List && community.isNotEmpty) ? community[0] : (community is Map<String, dynamic> ? community : null);

    return {
      ...raw,
      'username': isAnonymous ? 'Anonymous' : (profile['username'] ?? 'User'),
      'avatar_url': isAnonymous ? null : profile['avatar_url'],
      'timeAgo': timeAgo,
      'mood': raw['mood'] ?? 'Neutral',
      'moodEmoji': MoodService.getMoodEmoji(raw['mood'] ?? 'Neutral'),
      'isVerified': isAnonymous ? false : (profile['is_verified'] == true),
      'community_username': commMap?['username'],
    };
  }

  void _showAddToOrbitDialog() {
    showDialog(
      context: context,
      builder: (context) => AddToOrbitDialog(
        userId: widget.userId,
        username: _profile?['username'] ?? 'User',
        avatarUrl: _profile?['avatar_url'],
        onAdded: _loadData,
      ),
    );
  }

  Future<void> _removeFromOrbit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Orbit?'),
        content: Text('Are you sure you want to remove ${_profile?['username']} from your orbit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _orbitService.removeFromOrbit(widget.userId);
        await _loadData(); // Refresh status
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing from orbit: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null && widget.initialAvatarUrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _buildWebLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final username = _profile?['username']?.toString() ?? 'Loading...';
    final avatarUrl = _profile?['avatar_url']?.toString() ?? widget.initialAvatarUrl;
    final joinDate = _profile?['created_at'] != null ? DateFormat('MMMM d, yyyy').format(DateTime.parse(_profile!['created_at'])) : 'Recently';
    
    final bgColor = isDark ? AurbitWebTheme.darkBg : const Color(0xFFDAE0E6); // Aurbit-themed background
    final cardColor = isDark ? AurbitWebTheme.darkCard : Colors.white;
    final borderColor = isDark ? AurbitWebTheme.darkBorder : const Color(0xFFEDEFF1);
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AurbitWebTheme.darkTopbar : Colors.white,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.of(context).pop()),
        title: Text(username, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        centerTitle: false,
        actions: [
          IconButton(icon: Icon(Icons.share_outlined, color: textColor, size: 20), onPressed: () {}),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner & Profile Header
            Container(
              color: isDark ? AurbitWebTheme.darkTopbar : Colors.white,
              width: double.infinity,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark ? [const Color(0xFF1A1A1A), const Color(0xFF333333)] : [const Color(0xFF0079D3), const Color(0xFF53A6E8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Profile Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -20),
                              child: Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? AurbitWebTheme.darkTopbar : Colors.white, width: 4),
                                  color: cardColor,
                                ),
                                child: ClipOval(child: _buildAvatar(avatarUrl, isDark)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(username, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
                                  Text('@$username', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pills Tabs
                      _buildPillTabs(isDark),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Main Content Area
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Feed (Left/Center)
                      Expanded(
                        flex: 2,
                        child: _buildTabContentView(isDark, textColor, subColor!, cardColor),
                      ),
                      const SizedBox(width: 24),
                      // Sidebar (Right)
                      SizedBox(
                        width: 312,
                        child: Column(
                          children: [
                            _buildAboutCard(isDark, cardColor, borderColor, textColor, subColor, joinDate),
                            const SizedBox(height: 16),
                            _buildMoodSideCard(isDark, cardColor, borderColor, textColor, subColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final username = _profile?['username']?.toString() ?? 'Loading...';
    final avatarUrl = _profile?['avatar_url']?.toString() ?? widget.initialAvatarUrl;
    final bio = _profile?['bio']?.toString() ?? 'No bio yet';
    final currentMood = _profile?['current_mood']?.toString();
    
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.of(context).pop()),
        title: Text(username, style: theme.textTheme.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.primaryColor.withOpacity(0.8), theme.primaryColor])),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: cardColor, border: Border.all(color: cardColor, width: 3)),
                        child: ClipOval(child: _buildAvatar(avatarUrl, isDark)),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(username, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 4),
                          Text('@$username', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                          const SizedBox(height: 12),
                          if (currentMood != null) _buildMoodPill(currentMood, isDark, textColor, theme),
                          const SizedBox(height: 12),
                          Text(bio, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: secondaryTextColor, height: 1.4)),
                          const SizedBox(height: 16),
                          if (!_isMe) _buildActionButton(theme, isDark, secondaryTextColor!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: theme.primaryColor,
                  unselectedLabelColor: secondaryTextColor,
                  indicatorColor: theme.primaryColor,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [Tab(text: 'POSTS'), Tab(text: 'COMMENTS'), Tab(text: 'MOOD')],
                ),
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(isDark, textColor, secondaryTextColor!, cardColor),
            _buildCommentsTab(isDark, textColor, secondaryTextColor!, cardColor),
            _buildMoodTab(isDark, textColor, secondaryTextColor!, cardColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(bool isDark, Color cardColor, Color borderColor, Color textColor, Color subColor, String joinDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ABOUT USER', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: subColor, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Text(_profile?['bio'] ?? 'No bio yet', style: GoogleFonts.inter(fontSize: 13, color: textColor, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            children: [
              _statItem('Influence', '0', subColor, textColor), // Replace with actual influence if available
              _statItem('Joined', joinDate, subColor, textColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem('Inner Orbit', _innerCount.toString(), subColor, textColor),
              _statItem('Outer Orbit', _outerCount.toString(), subColor, textColor),
            ],
          ),
          const SizedBox(height: 24),
          if (!_isMe) _buildActionButton(Theme.of(context), isDark, subColor),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color sub, Color text) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: sub)),
        ],
      ),
    );
  }

  Widget _buildMoodSideCard(bool isDark, Color cardColor, Color borderColor, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MOOD HISTORY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: subColor, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          if (_moodHistory.isEmpty) 
            Text('No history', style: TextStyle(color: subColor, fontSize: 12))
          else 
            Column(
              children: _moodHistory.take(5).map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Text(MoodService.getMoodEmoji(log.mood), style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(log.mood, style: TextStyle(color: textColor, fontSize: 13)),
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPillTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: (index) => setState(() {}),
        tabs: [
          _tabPill('Posts', _tabController.index == 0, isDark),
          _tabPill('Comments', _tabController.index == 1, isDark),
          _tabPill('Mood', _tabController.index == 2, isDark),
        ],
      ),
    );
  }

  Widget _tabPill(String label, bool active, bool isDark) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final activeBg = isDark ? Colors.grey[800] : const Color(0xFFF6F7F8);
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? activeColor : Colors.grey)),
      ),
    );
  }

  Widget _buildTabContentView(bool isDark, Color textColor, Color subColor, Color cardColor) {
    return SizedBox(
      height: 800, // Should be dynamic but for web 3-col it's fine in single child scroll
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(isDark, textColor, subColor, cardColor),
          _buildCommentsTab(isDark, textColor, subColor, cardColor),
          _buildMoodTab(isDark, textColor, subColor, cardColor),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, bool isDark) {
    if (avatarUrl == null) return Icon(Icons.person, size: 40, color: isDark ? Colors.grey[600] : Colors.grey[400]);
    if (avatarUrl.contains('.svg') || avatarUrl.contains('dicebear')) return SvgPicture.network(avatarUrl, fit: BoxFit.cover);
    return Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, size: 40));
  }

  Widget _buildMoodPill(String mood, bool isDark, Color textColor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MoodService.getMoodEmoji(mood), style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(mood, style: theme.textTheme.bodyMedium?.copyWith(color: textColor.withOpacity(0.8), fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, bool isDark, Color secondaryTextColor) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: _orbitStatus != null
          ? OutlinedButton(
              onPressed: _removeFromOrbit,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                side: BorderSide(color: _orbitStatus == 'inner' ? theme.primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[400]!)),
              ),
              child: Text(_orbitStatus == 'inner' ? 'Inner Orbit' : 'Outer Orbit', style: TextStyle(color: _orbitStatus == 'inner' ? theme.primaryColor : secondaryTextColor, fontWeight: FontWeight.w600, fontSize: 12)),
            )
          : ElevatedButton(
              onPressed: _isPending ? null : _showAddToOrbitDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(_isPending ? 'Pending' : 'Add to Orbit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
    );
  }

  Widget _buildPostsTab(bool isDark, Color textColor, Color secondaryTextColor, Color cardColor) {
    if (_userPosts.isEmpty) return _buildEmptyState(Icons.article_outlined, 'No posts yet');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final community = post['communities'];
        final commHandle = community != null ? 'c/${community['username']}' : null;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: _mapPost(post)))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: isDark ? AurbitWebTheme.darkBorder : const Color(0xFFEDEFF1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (commHandle != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(commHandle, style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 11, fontWeight: FontWeight.bold))),
                Text(post['content'] ?? '', style: TextStyle(color: textColor, fontSize: 15)),
                const SizedBox(height: 8),
                Text(DateFormat('MMM d, yyyy').format(DateTime.parse(post['created_at'])), style: TextStyle(color: secondaryTextColor, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTab(bool isDark, Color textColor, Color secondaryTextColor, Color cardColor) {
    if (_userComments.isEmpty) return _buildEmptyState(Icons.chat_bubble_outline, 'No comments yet');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userComments.length,
      itemBuilder: (context, index) {
        final comment = _userComments[index];
        final post = comment['posts'];
        final postContent = post?['content'] ?? 'deleted post';
        return GestureDetector(
          onTap: () { if (post != null) Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: _mapPost(post)))); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: isDark ? AurbitWebTheme.darkBorder : const Color(0xFFEDEFF1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment['content'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 15)),
                const SizedBox(height: 8),
                Text('on: $postContent', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaryTextColor, fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text(DateFormat('MMM d, yyyy').format(DateTime.parse(comment['created_at'])), style: TextStyle(color: secondaryTextColor, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodTab(bool isDark, Color textColor, Color secondaryTextColor, Color cardColor) {
    if (_moodHistory.isEmpty) return _buildEmptyState(Icons.history, 'No mood history');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _moodHistory.length,
      itemBuilder: (context, index) {
        final log = _moodHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: isDark ? AurbitWebTheme.darkBorder : const Color(0xFFEDEFF1))),
          child: ListTile(
            leading: Text(MoodService.getMoodEmoji(log.mood), style: const TextStyle(fontSize: 20)),
            title: Text(log.mood, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(DateFormat('MMM d, h:mm a').format(log.createdAt.toLocal()), style: TextStyle(color: secondaryTextColor, fontSize: 11)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData iconData, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 40, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.color});
  final TabBar _tabBar;
  final Color color;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
