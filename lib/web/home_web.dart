import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../shared/widgets/scale_button.dart';
import '../web/aurbit_web_theme.dart';
import '../theme/theme_service.dart';
import '../profile/profile_screen.dart';
import '../notifications/notification_screen.dart';
import '../search/search_results_screen.dart';
import '../community/community_feed_screen.dart';
import '../community/community_post_detail_screen.dart';
import '../space/post_detail_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/notification_service.dart';
import 'dart:async';

// ─── Aurbit Web Design Tokens ──────────────────────────────────────────────
class HomeWeb extends StatefulWidget {
  final int currentIndex;
  final Widget currentPage;
  final Function(int) onTabTapped;
  final int unreadMessageCount;
  final int notificationCount;

  const HomeWeb({
    super.key,
    required this.currentIndex,
    required this.currentPage,
    required this.onTabTapped,
    required this.unreadMessageCount,
    required this.notificationCount,
  });

  @override
  State<HomeWeb> createState() => _HomeWebState();
}

class _HomeWebState extends State<HomeWeb> {
  String? _userAvatarUrl;
  String _userName = 'User';
  List<Map<String, dynamic>> _suggestedCommunities = [];
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _suggestionsOverlay;
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isSearchingSuggestions = false;
  String _selectedSearchCategory = 'All'; // 'All', 'Posts', 'Community', 'Person'
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchSuggestedCommunities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _hideSuggestions();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url, username')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _userAvatarUrl = data['avatar_url'];
            _userName = data['username'] ?? 'User';
          });
        }
      } catch (e) {
        debugPrint('Error fetching user profile for web topbar: $e');
      }
    }
  }

  Future<void> _fetchSuggestedCommunities() async {
    try {
      final data = await Supabase.instance.client
          .from('communities')
          .select('id, name, username, members_count, active_count')
          .order('members_count', ascending: false)
          .limit(3);

      if (!mounted) return;
      setState(() {
        _suggestedCommunities = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching suggested communities: $e');
    }
  }

  void _openSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    _hideSuggestions();
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(initialQuery: query),
      ),
    );
  }

  void _onSearchChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSearchSuggestions(val);
    });
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _hideSuggestions();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearchingSuggestions = true;
    });

    try {
      final orSafe = q.replaceAll(',', ' ');
      final like = '%$q%';

      final results = await Future.wait([
        Supabase.instance.client
            .from('communities')
            .select('id, name, username, members_count, description, active_count')
            .or('name.ilike.%$orSafe%,username.ilike.%$orSafe%')
            .order('members_count', ascending: false)
            .limit(5),
        Supabase.instance.client
            .from('posts')
            .select('id, content, user_id, mood, created_at, profile:user_id(username, avatar_url)')
            .ilike('content', like)
            .limit(3),
        Supabase.instance.client
            .from('community_posts')
            .select('id, content, user_id, community_id, mood, created_at, profile:user_id(username, avatar_url, is_verified), communities(name, username)')
            .ilike('content', like)
            .limit(5),
        Supabase.instance.client
            .from('profiles')
            .select('id, username, avatar_url, is_verified')
            .ilike('username', like)
            .limit(5),
      ]);

      if (!mounted) return;

      final comms = (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)..['type'] = 'community').toList();
      final posts = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)..['type'] = 'post').toList();
      final cposts = (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)..['type'] = 'community_post').toList();
      final people = (results[3] as List).map((e) => Map<String, dynamic>.from(e as Map)..['type'] = 'person').toList();

      setState(() {
        _searchSuggestions = [...comms, ...posts, ...cposts, ...people];
        _isSearchingSuggestions = false;
      });

      if (_searchSuggestions.isNotEmpty) {
        _showSuggestions();
      } else {
        _hideSuggestions();
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      if (mounted) setState(() => _isSearchingSuggestions = false);
    }
  }

  void _showSuggestions() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = _createSuggestionsOverlay();
    Overlay.of(context).insert(_suggestionsOverlay!);
  }

  void _hideSuggestions() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
  }

  OverlayEntry _createSuggestionsOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E26) : Colors.white;
    final border = isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0);
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white60 : Colors.black54;

    return OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setOverlayState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bg = isDark ? const Color(0xFF1E1E26) : Colors.white;
          final border = isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0);
          final text = isDark ? Colors.white : const Color(0xFF0F172A);
          final sub = isDark ? Colors.white60 : Colors.black54;

          final filtered = _searchSuggestions.where((s) {
            if (_selectedSearchCategory == 'All') return true;
            if (_selectedSearchCategory == 'Posts') return s['type'] == 'post' || s['type'] == 'community_post';
            if (_selectedSearchCategory == 'Community') return s['type'] == 'community';
            if (_selectedSearchCategory == 'Person') return s['type'] == 'person';
            return true;
          }).toList();

          final screenWidth = MediaQuery.of(context).size.width;
          final overlayWidth = screenWidth < 480 ? screenWidth - 32 : 440.0;

          return Positioned(
            width: overlayWidth,
            child: CompositedTransformFollower(
              link: _searchLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 40),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                color: bg,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category Bar - Scrollable on mobile
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: border)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: ['All', 'Posts', 'Community', 'Person'].map((cat) {
                              final isActive = _selectedSearchCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: GestureDetector(
                                  onTap: () {
                                    setOverlayState(() {
                                      _selectedSearchCategory = cat;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isActive ? AurbitWebTheme.accentPrimary.withOpacity(0.12) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      cat,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                        color: isActive ? AurbitWebTheme.accentPrimary : sub,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // Results List
                      Flexible(
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('No results found for $_selectedSearchCategory', style: GoogleFonts.inter(fontSize: 13, color: sub)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(color: border, height: 1),
                                itemBuilder: (context, index) {
                                  final s = filtered[index];
                                  final type = s['type'];

                                  if (type == 'community') {
                                    return ListTile(
                                      leading: const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Color(0xFF7C3AED),
                                        child: Icon(Icons.groups_rounded, color: Colors.white, size: 16),
                                      ),
                                      title: _buildHighlightedText(
                                        context, 
                                        s['name']?.toString() ?? 'Community', 
                                        _searchController.text, 
                                        GoogleFonts.inter(fontSize: 13, color: text, fontWeight: FontWeight.w600)
                                      ),
                                      subtitle: Text('${s['members_count'] ?? 0} members • c/${s['username'] ?? ''}', style: GoogleFonts.inter(fontSize: 11, color: sub)),
                                      dense: true,
                                      onTap: () {
                                        _hideSuggestions();
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityFeedScreen(community: s)));
                                      },
                                    );
                                  }

                                  if (type == 'person') {
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: border,
                                        backgroundImage: (s['avatar_url'] as String?) != null ? NetworkImage(s['avatar_url']) : null,
                                        child: s['avatar_url'] == null ? const Icon(Icons.person, size: 16) : null,
                                      ),
                                      title: _buildHighlightedText(
                                        context, 
                                        s['username']?.toString() ?? 'User', 
                                        _searchController.text, 
                                        GoogleFonts.inter(fontSize: 13, color: text, fontWeight: FontWeight.w600)
                                      ),
                                      subtitle: Text('Member since joining', style: GoogleFonts.inter(fontSize: 11, color: sub)),
                                      dense: true,
                                      onTap: () {
                                        _hideSuggestions();
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: s['id'])));
                                      },
                                    );
                                  }

                                  final content = (s['content'] ?? '').toString();
                                  final snippet = content.length > 50 ? '${content.substring(0, 47)}...' : content;
                                  final user = s['profile']?['username'] ?? 'User';

                                  return ListTile(
                                    leading: Icon(type == 'post' ? Icons.article_outlined : Icons.forum_outlined, color: sub, size: 20),
                                    title: _buildHighlightedText(
                                      context, 
                                      snippet, 
                                      _searchController.text, 
                                      GoogleFonts.inter(fontSize: 13, color: text)
                                    ),
                                    subtitle: Text('By $user', style: GoogleFonts.inter(fontSize: 11, color: sub)),
                                    dense: true,
                                    onTap: () {
                                      _hideSuggestions();
                                      if (type == 'post') {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: _mapRawPost(s))));
                                      } else {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: _mapRawCommunityPost(s))));
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _mapRawPost(Map<String, dynamic> s) {
    final profile = s['profile'] as Map<String, dynamic>?;
    final createdAt = s['created_at']?.toString();
    return {
      'id': s['id']?.toString() ?? '',
      'content': s['content']?.toString() ?? '',
      'user_id': s['user_id']?.toString() ?? '',
      'mood': s['mood'] ?? 'Neutral',
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'is_anonymous': s['is_anonymous'] == true,
      'username': profile?['username'] ?? 'User',
      'avatar_url': profile?['avatar_url'],
      'is_verified': profile?['is_verified'] ?? false,
      'isVerified': profile?['is_verified'] ?? false,
      'timeAgo': _calculateTimeAgo(createdAt),
      'community_username': 'space',
    };
  }

  Map<String, dynamic> _mapRawCommunityPost(Map<String, dynamic> s) {
    final profile = s['profile'] as Map<String, dynamic>?;
    final communities = s['communities'] as Map<String, dynamic>?;
    final createdAt = s['created_at']?.toString();
    return {
      'id': s['id']?.toString() ?? '',
      'content': s['content']?.toString() ?? '',
      'user_id': s['user_id']?.toString() ?? '',
      'community_id': s['community_id']?.toString() ?? '',
      'mood': s['mood'] ?? 'Neutral',
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'is_anonymous': s['is_anonymous'] == true,
      'username': profile?['username'] ?? 'User',
      'avatar_url': profile?['avatar_url'],
      'is_verified': profile?['is_verified'] ?? false,
      'isVerified': profile?['is_verified'] ?? false,
      'timeAgo': _calculateTimeAgo(createdAt),
      'community_username': communities?['username'] ?? 'community',
    };
  }

  String _calculateTimeAgo(String? iso) {
    if (iso == null) return 'now';
    try {
      final created = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(created);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'now';
    }
  }

  Widget _buildHighlightedText(BuildContext context, String text, String query, TextStyle baseStyle) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    
    final matches = query.toLowerCase().allMatches(text.toLowerCase());
    if (matches.isEmpty) return Text(text, style: baseStyle);

    final highlightStyle = baseStyle.copyWith(
      backgroundColor: AurbitWebTheme.accentPrimary.withOpacity(0.25),
      color: AurbitWebTheme.accentPrimary,
      fontWeight: FontWeight.bold,
    );

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(text: text.substring(match.start, match.end), style: highlightStyle));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return Text.rich(TextSpan(children: spans, style: baseStyle));
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AurbitWebTheme.darkBg    : AurbitWebTheme.lightBg;
    final border = isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      drawer: isMobile ? Drawer(
        width: 280,
        backgroundColor: isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightSidebar,
        child: _buildSidebarContent(context, isDark, border),
      ) : null,
      body: Column(
        children: [
          _buildTopBar(context, isDark, border, isMobile),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile) _buildDesktopSidebar(context, isDark, border),
                Expanded(child: widget.currentPage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, bool isDark, Color border, bool isMobile) {
    final topBg     = isDark ? AurbitWebTheme.darkTopbar  : AurbitWebTheme.lightTopbar;
    final textColor = isDark ? AurbitWebTheme.darkText     : AurbitWebTheme.lightText;
    final subColor  = isDark ? AurbitWebTheme.darkSubtext  : AurbitWebTheme.lightSubtext;
    final inputBg   = isDark ? const Color(0xFF252530)     : const Color(0xFFF1F3F5);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: topBg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: Icon(Icons.menu_rounded, color: textColor),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 4),
          ],
          if (screenWidth > 600) ...[
            // ─ Logo ─
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AurbitWebTheme.accentPrimary, Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Aurbit',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AurbitWebTheme.accentPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],

          // ─ Search ─
          Expanded( // Use Expanded to take all available width on mobile
            child: CompositedTransformTarget(
              link: _searchLayerLink,
              child: Container(
                height: 36,
                constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 360 : 450),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: subColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search Aurbit...',
                          hintStyle: GoogleFonts.inter(color: subColor, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: _isSearchingSuggestions
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: subColor),
                                  ),
                                )
                              : null,
                        ),
                        style: GoogleFonts.inter(color: textColor, fontSize: 13),
                        textInputAction: TextInputAction.search,
                        onChanged: _onSearchChanged,
                        onSubmitted: _openSearch,
                        onTap: () {
                          if (_searchSuggestions.isNotEmpty) _showSuggestions();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // ─ Action buttons ─
          _topBarIconBtn(
            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            'Toggle theme',
            isDark,
            () => ThemeService().toggleTheme(),
          ),
          const SizedBox(width: 8),
          _topBarIconBtn(
            Icons.notifications_none_rounded,
            'Notifications',
            isDark,
            () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
              // Counts are refreshed by the polling/subscriptions in the parent MainScreen
            },
            hasBadge: (widget.unreadMessageCount + widget.notificationCount) > 0,
          ),

          const SizedBox(width: 12),

          // ─ User chip ─
          ScaleButton(
            onTap: () {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _avatarWidget(isDark, size: 26),
                  if (screenWidth > 480) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Text(
                        _userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: subColor),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBarIconBtn(IconData icon, String tooltip, bool isDark, VoidCallback onTap, {bool hasBadge = false}) {
    return Tooltip(
      message: tooltip,
      child: ScaleButton(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText),
            ),
            if (hasBadge)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF1E1E26) : Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEFT SIDEBAR
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopSidebar(BuildContext context, bool isDark, Color border) {
    final sidebarBg = isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightSidebar;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: border, width: 1)),
      ),
      child: _buildSidebarContent(context, isDark, border),
    );
  }

  Widget _buildSidebarContent(BuildContext context, bool isDark, Color border) {
    final textColor = isDark ? AurbitWebTheme.darkText     : AurbitWebTheme.lightText;
    final subColor  = isDark ? AurbitWebTheme.darkSubtext  : AurbitWebTheme.lightSubtext;

    final navItems = [
      (0, 'Space',       Icons.home_rounded,          Icons.home_outlined),
      (1, 'Communities', Icons.groups_rounded,          Icons.groups_outlined),
      (3, 'Orbit',       Icons.blur_circular_sharp,     Icons.blur_on_outlined),
      (4, 'Chat',        Icons.chat_bubble_rounded,     Icons.chat_bubble_outline_rounded),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
            ...navItems.map((item) => _SidebarNavItem(
              index: item.$1,
              label: item.$2,
              activeIcon: item.$3,
              inactiveIcon: item.$4,
              isSelected: widget.currentIndex == item.$1,
              badge: item.$1 == 4 ? widget.unreadMessageCount : 0,
              onTap: widget.onTabTapped,
            )),

            const SizedBox(height: 8),
            _sidebarDivider(border),
            const SizedBox(height: 8),

            // ─ Create post button ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ScaleButton(
                onTap: () => widget.onTabTapped(2),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AurbitWebTheme.accentPrimary, Color(0xFF4F46E5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AurbitWebTheme.accentPrimary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Create Post', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            _sidebarDivider(border),
            const SizedBox(height: 8),

            // ─ Communities ─
            _sidebarSectionLabel('COMMUNITIES', subColor),
            if (_suggestedCommunities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No communities yet',
                  style: GoogleFonts.inter(fontSize: 12, color: subColor),
                ),
              )
            else
              ..._suggestedCommunities.map((community) => _communityItem(
                    (community['active_count'] ?? 0) > 0 ? '🔥' : '💬',
                    community['name']?.toString() ?? 'Community',
                    _formatMemberCount(community['members_count']),
                    isDark,
                    textColor,
                    subColor,
                    onTap: () => widget.onTabTapped(1),
                  )),

            const SizedBox(height: 8),
            _sidebarDivider(border),
            const SizedBox(height: 8),

            // ─ Resources ─
            _sidebarSectionLabel('RESOURCES', subColor),
            _simpleItem(Icons.settings_outlined,        'Settings',     subColor),
            _simpleItem(Icons.help_outline_rounded,     'Help',         subColor),
            _simpleItem(Icons.shield_outlined,          'Privacy',      subColor),

            // ─ Logout ─
            _sidebarSectionLabel('ACCOUNT', subColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ScaleButton(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Log Out?'),
                      content: const Text('Are you sure you want to log out of Aurbit?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await Supabase.instance.client.auth.signOut();
                    // Navigation will be handled by auth listener in main.dart or similar
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 17, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Text('Log Out', style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Your space. Your pace. ✨',
                style: GoogleFonts.inter(color: subColor, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
  }

  Widget _sidebarDivider(Color border) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Divider(color: border, height: 1),
  );

  Widget _sidebarSectionLabel(String label, Color subColor) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
    child: Text(label, style: GoogleFonts.inter(color: subColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  String _formatMemberCount(dynamic value) {
    final count = (value as num?)?.toInt() ?? 0;
    if (count >= 1000) {
      final k = count / 1000;
      return k >= 10 ? '${k.toStringAsFixed(0)}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$count';
  }

  Widget _communityItem(
    String emoji,
    String name,
    String members,
    bool isDark,
    Color textColor,
    Color subColor, {
    VoidCallback? onTap,
  }) {
    final itemBg = isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ScaleButton(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: itemBg, shape: BoxShape.circle),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                    Text('$members members', style: GoogleFonts.inter(fontSize: 10, color: subColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleItem(IconData icon, String label, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ScaleButton(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: subColor),
              const SizedBox(width: 10),
              Text(label, style: GoogleFonts.inter(fontSize: 13, color: subColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarWidget(bool isDark, {double size = 32}) {
    final bg = isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: ClipOval(
        child: _userAvatarUrl != null
            ? (_userAvatarUrl!.contains('.svg') || _userAvatarUrl!.contains('dicebear'))
                ? SvgPicture.network(_userAvatarUrl!, fit: BoxFit.cover)
                : Image.network(_userAvatarUrl!, fit: BoxFit.cover)
            : Icon(Icons.person_rounded, size: size * 0.55, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
    );
  }
}

// ─── Sidebar Nav Item Widget ───────────────────────────────────────────────
class _SidebarNavItem extends StatefulWidget {
  final int index;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final int badge;
  final Function(int) onTap;

  const _SidebarNavItem({
    required this.index,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final selColor  = AurbitWebTheme.accentPrimary;
    final selBg     = AurbitWebTheme.accentPrimary.withOpacity(0.09);
    final hoverBg   = isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5);
    final idleColor = isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext;
    final textColor = isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.onTap(widget.index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: widget.isSelected ? selBg : (_hovered ? hoverBg : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      widget.isSelected ? widget.activeIcon : widget.inactiveIcon,
                      size: 20,
                      color: widget.isSelected ? selColor : idleColor,
                    ),
                    if (widget.badge > 0)
                      Positioned(
                        top: -4, right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text(
                            widget.badge > 99 ? '99+' : '${widget.badge}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected ? selColor : textColor,
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
