import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_feed_screen.dart';
import '../community/community_post_detail_screen.dart';
import '../space/post_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, required this.initialQuery});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _supabase = Supabase.instance.client;

  late final TextEditingController _queryController;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _globalPosts = [];
  List<Map<String, dynamic>> _communityPosts = [];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _runSearch();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  static String _timeAgoFromIso(String? iso) {
    if (iso == null) return '';
    try {
      final created = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(created);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  static String _snippet(String? text, {int max = 140}) {
    final t = (text ?? '').replaceAll('\n', ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trimRight()}...';
  }

  Map<String, dynamic> _mapGlobalPost(Map<String, dynamic> raw) {
    final profile = raw['profile'];
    final profileMap = profile is Map ? Map<String, dynamic>.from(profile) : <String, dynamic>{};
    final isAnonymous = raw['is_anonymous'] == true;

    return {
      'id': raw['id'],
      'user_id': raw['user_id'],
      'created_at': raw['created_at'],
      'is_anonymous': raw['is_anonymous'] == true,
      'mood': raw['mood'] ?? 'Neutral',
      'content': raw['content'] ?? '',
      'username': isAnonymous ? 'Anonymous' : (profileMap['username'] ?? 'User'),
      'avatar_url': isAnonymous ? null : profileMap['avatar_url'],
      'isVerified': isAnonymous ? false : ((profileMap['is_verified'] as bool?) ?? false),
      'timeAgo': _timeAgoFromIso(raw['created_at']?.toString()),
      'community_username': raw['community_username'] ?? 'space',
    };
  }

  Map<String, dynamic> _mapCommunityPost(Map<String, dynamic> raw) {
    final profile = raw['profile'];
    final profileMap = profile is Map ? Map<String, dynamic>.from(profile) : <String, dynamic>{};
    final isAnonymous = raw['is_anonymous'] == true;

    String? communityUsername;
    final comm = raw['communities'];
    if (comm is Map) {
      communityUsername = comm['username']?.toString();
    } else if (comm is List && comm.isNotEmpty && comm.first is Map) {
      communityUsername = (comm.first as Map)['username']?.toString();
    }

    return {
      'id': raw['id'],
      'user_id': raw['user_id'],
      'community_id': raw['community_id'],
      'created_at': raw['created_at'],
      'is_anonymous': raw['is_anonymous'] == true,
      'mood': raw['mood'] ?? 'Neutral',
      'content': raw['content'] ?? '',
      'username': isAnonymous ? 'Anonymous' : (profileMap['username'] ?? 'User'),
      'avatar_url': isAnonymous ? null : profileMap['avatar_url'],
      'is_verified': isAnonymous ? false : ((profileMap['is_verified'] as bool?) ?? false),
      'timeAgo': _timeAgoFromIso(raw['created_at']?.toString()),
      'community_username': communityUsername,
    };
  }

  Future<void> _runSearch() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _error = null;
        _communities = [];
        _globalPosts = [];
        _communityPosts = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final like = '%$q%';
      // Supabase `.or()` uses commas as separators, so keep query simple.
      final orSafe = q.replaceAll(',', ' ');

      final results = await Future.wait([
        _supabase
            .from('communities')
            .select('*')
            .or('name.ilike.%$orSafe%,username.ilike.%$orSafe%')
            .order('members_count', ascending: false)
            .limit(20),
        _supabase
            .from('posts')
            .select('*, profile:user_id(id, username, avatar_url, is_verified)')
            .ilike('content', like)
            .order('created_at', ascending: false)
            .limit(20),
        _supabase
            .from('community_posts')
            .select('*, profile:user_id(id, username, avatar_url, is_verified), communities (id, name, username)')
            .ilike('content', like)
            .order('created_at', ascending: false)
            .limit(20),
      ]);

      final communitiesRaw = results[0] as List<dynamic>;
      final globalPostsRaw = results[1] as List<dynamic>;
      final communityPostsRaw = results[2] as List<dynamic>;

      if (!mounted) return;
      setState(() {
        _communities = communitiesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _globalPosts = globalPostsRaw.map((e) => _mapGlobalPost(Map<String, dynamic>.from(e as Map))).toList();
        _communityPosts =
            communityPostsRaw.map((e) => _mapCommunityPost(Map<String, dynamic>.from(e as Map))).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = isDark ? const Color(0xFF1A1A20) : Colors.white;
    final border = isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFE8E8F0) : const Color(0xFF0F172A);
    final sub = isDark ? const Color(0xFF8B8BA0) : const Color(0xFF64748B);

    Widget sectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(
          title,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: sub),
        ),
      );
    }

    Widget emptyState() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No results for "${_queryController.text.trim()}"',
            style: GoogleFonts.inter(color: sub, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF141418) : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _queryController,
            decoration: InputDecoration(
              hintText: 'Search posts or communities...',
              hintStyle: GoogleFonts.inter(color: sub, fontSize: 14),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search_rounded, color: sub),
              suffixIcon: _queryController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(Icons.close_rounded, color: sub),
                      onPressed: () {
                        _queryController.clear();
                        setState(() {});
                        _runSearch();
                      },
                    ),
            ),
            style: GoogleFonts.inter(color: text, fontSize: 14),
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _runSearch(),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Search failed:\n$_error',
                      style: GoogleFonts.inter(color: sub, fontSize: 13, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ((_communities.isEmpty && _globalPosts.isEmpty && _communityPosts.isEmpty) ? emptyState() : ListView(
                  children: [
                    if (_communities.isNotEmpty) sectionTitle('Communities'),
                    ..._communities.map((c) {
                      final name = c['name']?.toString() ?? 'Community';
                      final handle = c['username']?.toString();
                      final members = c['members_count'];
                      final subtitle = [
                        if (handle != null && handle.isNotEmpty) 'c/$handle',
                        if (members != null) '$members members',
                      ].join(' - ');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Material(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityFeedScreen(community: Map<String, dynamic>.from(c)),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: border),
                                    ),
                                    child: Icon(Icons.group_rounded, color: sub, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: GoogleFonts.inter(color: text, fontWeight: FontWeight.w700)),
                                        if (subtitle.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(subtitle, style: GoogleFonts.inter(color: sub, fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: sub),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    if (_globalPosts.isNotEmpty) sectionTitle('Posts'),
                    ..._globalPosts.map((p) {
                      final username = p['username']?.toString() ?? 'User';
                      final timeAgo = p['timeAgo']?.toString() ?? '';
                      final content = _snippet(p['content']?.toString());

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Material(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PostDetailScreen(post: Map<String, dynamic>.from(p))),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          username,
                                          style:
                                              GoogleFonts.inter(color: text, fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      if (timeAgo.isNotEmpty)
                                        Text(timeAgo, style: GoogleFonts.inter(color: sub, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(content, style: GoogleFonts.inter(color: text, height: 1.3)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    if (_communityPosts.isNotEmpty) sectionTitle('Community Posts'),
                    ..._communityPosts.map((p) {
                      final username = p['username']?.toString() ?? 'User';
                      final timeAgo = p['timeAgo']?.toString() ?? '';
                      final content = _snippet(p['content']?.toString());
                      final handle = p['community_username']?.toString();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Material(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityPostDetailScreen(post: Map<String, dynamic>.from(p)),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          handle == null || handle.isEmpty ? username : '$username - c/$handle',
                                          style:
                                              GoogleFonts.inter(color: text, fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      if (timeAgo.isNotEmpty)
                                        Text(timeAgo, style: GoogleFonts.inter(color: sub, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(content, style: GoogleFonts.inter(color: text, height: 1.3)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                  ],
                )),
    );
  }
}
