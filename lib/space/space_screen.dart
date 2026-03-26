import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/theme_service.dart';
import '../profile/profile_screen.dart';
import '../services/notification_service.dart';
import '../notifications/notification_screen.dart';
import 'feed_post_card.dart';
import '../services/mood_service.dart';
import '../widgets/mood_selector.dart';
import 'package:flutter/foundation.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class SpaceScreen extends StatefulWidget {
  final int notificationCount;
  const SpaceScreen({super.key, this.notificationCount = 0});

  @override
  State<SpaceScreen> createState() => _SpaceScreenState();
}


class _SpaceScreenState extends State<SpaceScreen> with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  String _currentMood = 'Neutral';
  String? _userAvatarUrl;

  /// null = show all, otherwise one of: 'private','inner_orbit','outer_orbit','anonymous_public'
  String? _selectedPrivacyCircle;

  /// Maps sidebar label → DB privacy_level value
  static const _circleToLevel = {
    'Private':          'private',
    'Inner Orbit':      'inner_orbit',
    'Outer Orbit':      'outer_orbit',
    'Anonymous Public': 'anonymous_public',
  };

  // ── Today's Vibe state ─────────────────────────────────────────────────────
  late final DateTime _sessionStart;
  Timer? _vibeTimer;
  Duration _timeActive = Duration.zero;
  String _dominantMood = '—';
  String _dominantMoodEmoji = '😐';
  int _newConnectionsToday = 0;

  late final RealtimeChannel _postsChannel;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserAvatar();
    _fetchCurrentMood();
    _fetchPosts();
    _fetchVibeStats();
    _subscribeToPosts();
    // Update elapsed time every minute
    _vibeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _timeActive = DateTime.now().difference(_sessionStart));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh mood when user returns to the app
    if (state == AppLifecycleState.resumed) {
      _fetchCurrentMood();
    }
  }

  @override
  void dispose() {
    _vibeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    Supabase.instance.client.removeChannel(_postsChannel);
    super.dispose();
  }

  void _subscribeToPosts() {
    _postsChannel = Supabase.instance.client
        .channel('public:all_feed_posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newPostId = payload.newRecord['id'];
              final postUserId = payload.newRecord['user_id'];
              final postPrivacy = payload.newRecord['privacy_level'];

              bool matches = true;
              if (_activeFilter == 2 && postPrivacy != 'anonymous_public') {
                matches = false;
              } else if (_activeFilter == 3) {
                // For Following: match if it's among friends OR current user
                final userId = Supabase.instance.client.auth.currentUser?.id;
                // Since friendIds might be async fetched, we do a quick check if friendIds contains postUserId
                // but friendIds is locally available in _fetchPosts, not easily in this callback.
                // We'll proceed with fetch and the _fetchSinglePost handles the filter eventually.
              }

              if (newPostId != null && matches) {
                await _fetchSinglePost(newPostId.toString(), 'posts');
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
              _handlePostUpdate(payload.newRecord);
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              _handlePostDelete(payload.oldRecord['id']);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newPostId = payload.newRecord['id'];
              final communityId = payload.newRecord['community_id'];
              
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId != null && communityId != null) {
                 final isMember = await Supabase.instance.client
                    .from('community_members')
                    .select()
                    .eq('community_id', communityId)
                    .eq('user_id', userId)
                    .maybeSingle();
                 
                 if (isMember != null && newPostId != null) {
                   await _fetchSinglePost(newPostId, 'community_posts');
                 }
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
              _handlePostUpdate(payload.newRecord);
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              _handlePostDelete(payload.oldRecord['id']);
            }
          },
        )
        .subscribe();
  }

  void _handlePostUpdate(Map<String, dynamic> updatedRecord) {
    if (mounted) {
      setState(() {
        final index = _posts.indexWhere((p) => p['id'] == updatedRecord['id']);
        if (index != -1) {
          final existing = _posts[index];
          _posts[index] = {
            ...existing,
            'content': updatedRecord['content'],
            'mood': updatedRecord['mood'],
            'moodEmoji': _getMoodEmoji(updatedRecord['mood']),
          };
        }
      });
    }
  }

  void _handlePostDelete(dynamic deletedId) {
    if (mounted && deletedId != null) {
      setState(() {
        _posts.removeWhere((p) => p['id'] == deletedId);
      });
    }
  }

  Future<void> _fetchSinglePost(String postId, String tableName) async {
    try {
      final isCommunityTable = tableName == 'community_posts';
      final selectedLevel = _selectedPrivacyCircle;

      // When a privacy circle is selected, hide community posts entirely.
      if (selectedLevel != null && isCommunityTable) {
        return;
      }
      
      // Select depends on table
      String selectStr = '*';
      if (isCommunityTable) {
        selectStr = '*, communities (username)';
      }

      final response = await Supabase.instance.client
          .from(tableName)
          .select(selectStr)
          .eq('id', postId)
          .single();
      
      final post = response;
      final postPrivacyLevel = post['privacy_level'] as String?;

      // Respect active privacy-circle filter for realtime inserts.
      if (selectedLevel != null && postPrivacyLevel != selectedLevel) {
        return;
      }
      final postUserId = post['user_id'];
      
      // Fetch profile
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('username, avatar_url, is_verified')
          .eq('id', postUserId)
          .single();
      
      final profile = profileResponse;

      if (mounted) {
        setState(() {
          final isAnonymous = post['is_anonymous'] ?? false;
          final timeAgo = 'Just now';

          String? commHandle;
          if (isCommunityTable) {
            final communityDataRaw = post['communities'];
            final Map<String, dynamic>? community = (communityDataRaw is List) 
                ? (communityDataRaw.isNotEmpty ? communityDataRaw[0] as Map<String, dynamic> : null) 
                : communityDataRaw as Map<String, dynamic>?;
            commHandle = community?['username'];
          }

          final personUsername = isAnonymous ? 'Anonymous' : (profile['username'] ?? 'User');
          
          final newPostMap = {
            'id': post['id'],
            'user_id': post['user_id'],
            'username': personUsername,
            'avatar_url': isAnonymous ? null : profile['avatar_url'],
            'timeAgo': timeAgo,
            'mood': post['mood'] ?? 'Neutral',
            'moodEmoji': _getMoodEmoji(post['mood']),
            'content': post['content'] ?? '',
            'relateCount': 0,
            'supportCount': 0,
            'community_username': commHandle,
            'isVerified': isAnonymous ? false : ((profile['is_verified'] as bool?) ?? false),
          };
          
          _posts.insert(0, newPostMap);
        });
      }
    } catch (e) {
      debugPrint('Error fetching single post: $e');
    }
  }

  Future<void> _fetchPosts() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // 1. Fetch joined community IDs
      List<String> joinedCommunityIds = [];
      if (userId != null) {
        final memberships = await Supabase.instance.client
            .from('community_members')
            .select('community_id')
            .eq('user_id', userId);
        joinedCommunityIds = (memberships as List).map((m) => m['community_id'] as String).toList();
      }

      List<String> friendIds = []; if (_activeFilter == 3 && userId != null) { final orbits = await Supabase.instance.client.from('user_orbits').select('friend_id').eq('user_id', userId); friendIds = (orbits as List).map((o) => o['friend_id'] as String).toList(); friendIds.add(userId); } // 2. Fetch Global Posts
      var globalQuery = Supabase.instance.client
          .from('posts')
          .select('*')
          .or('expires_at.gt.$nowIso,expires_at.is.null');

      if (_activeFilter == 2) {
        globalQuery = globalQuery.eq('privacy_level', 'anonymous_public');
      } else if (_activeFilter == 3) {
        globalQuery = globalQuery.inFilter('user_id', friendIds.isEmpty ? [userId ?? ''] : friendIds);
      } else if (_selectedPrivacyCircle != null) {
        globalQuery = globalQuery.eq('privacy_level', _selectedPrivacyCircle!);
      }
      final globalResponse = await globalQuery.order('created_at', ascending: false).limit(_activeFilter == 0 ? 30 : 50);
      final List<dynamic> globalData = globalResponse as List<dynamic>;

      // 3. Fetch Community Posts (if any communities joined)
      List<dynamic> communityData = [];
      if (userId != null && joinedCommunityIds.isNotEmpty && _selectedPrivacyCircle == null && _activeFilter != 2) {
        var commQuery = Supabase.instance.client
            .from('community_posts')
            .select('*, communities (username)');

        if (_activeFilter == 3 && friendIds.isNotEmpty) {
          commQuery = commQuery.inFilter('user_id', friendIds);
        }
        
        final communityResponse = await commQuery
            .inFilter('community_id', joinedCommunityIds)
            .order('created_at', ascending: false)
            .limit(_activeFilter == 0 ? 30 : 50);
        communityData = communityResponse as List<dynamic>;
      }

      // 4. Merge and sort
      final List<dynamic> allRawPosts = [...globalData, ...communityData];
      allRawPosts.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      // 5. Fetch profiles for all unique user IDs
      final allUserIds = allRawPosts.map((e) => e['user_id'] as String).toSet().toList();
      Map<String, dynamic> profilesMap = {};

      if (allUserIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, username, avatar_url, is_verified')
            .inFilter('id', allUserIds);
        profilesMap = {
          for (var p in (profilesResponse as List<dynamic>))
            p['id'] as String: p
        };
      }

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(allRawPosts.map((post) {
            final postUserId = post['user_id'];
            final profile = profilesMap[postUserId] ?? {};
            final isAnonymous = post['is_anonymous'] ?? false;
            final created = DateTime.parse(post['created_at']).toLocal();
            final now = DateTime.now();
            final diff = now.difference(created);
            String timeAgo;

            if (diff.inSeconds < 60) {
              timeAgo = 'Just now';
            } else if (diff.inMinutes < 60) {
              timeAgo = '${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              timeAgo = '${diff.inHours}h ago';
            } else {
              timeAgo = '${diff.inDays}d ago';
            }

            final communityDataRaw = post['communities'];
            final Map<String, dynamic>? community = (communityDataRaw is List) 
                ? (communityDataRaw.isNotEmpty ? communityDataRaw[0] as Map<String, dynamic> : null) 
                : communityDataRaw as Map<String, dynamic>?;

            final commHandle = community?['username'];
            final personUsername = isAnonymous ? 'Anonymous' : (profile['username'] ?? 'User');
            
            return {
              'id': post['id'],
              'user_id': post['user_id'],
              'username': personUsername,
              'avatar_url': isAnonymous ? null : profile['avatar_url'],
              'timeAgo': timeAgo,
              'mood': post['mood'] ?? 'Neutral',
              'moodEmoji': _getMoodEmoji(post['mood']),
              'content': post['content'] ?? '',
              'privacy_level': post['privacy_level'] ?? '',
              'community_username': commHandle,
              'relateCount': 0,
              'supportCount': 0,
              'isVerified': isAnonymous ? false : ((profile['is_verified'] as bool?) ?? false),
            };
          }).toList());
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectPrivacyCircle(String label) {
    final level = _circleToLevel[label];
    setState(() {
      // Toggle off if already selected
      _selectedPrivacyCircle = (_selectedPrivacyCircle == level) ? null : level;
    });
    _fetchPosts();
  }

  String _getMoodEmoji(String? mood) {
    switch (mood) {
      case 'Happy': return '🤩';
      case 'Sad': return '😢';
      case 'Tired': return '😴';
      case 'Irritated': return '😤';
      case 'Lonely': return '😶‍🌫️';
      case 'Bored': return '😑';
      default: return '😐';
    }
  }

  Future<void> _fetchUserAvatar() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .single();
      if (mounted && data['avatar_url'] != null) {
        setState(() {
          _userAvatarUrl = data['avatar_url'];
        });
      }
    }
  }


  // ── Vibe stats ──────────────────────────────────────────────────────────────
  Future<void> _fetchVibeStats() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final todayStart = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .toUtc()
        .toIso8601String();

    try {
      // 1. Dominant mood today from mood_logs
      final moodLogs = await Supabase.instance.client
          .from('mood_logs')
          .select('mood')
          .eq('user_id', userId)
          .gte('created_at', todayStart);

      if (moodLogs != null && (moodLogs as List).isNotEmpty) {
        final counts = <String, int>{};
        for (final log in moodLogs) {
          final m = log['mood']?.toString() ?? 'Neutral';
          counts[m] = (counts[m] ?? 0) + 1;
        }
        final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        if (mounted) {
          setState(() {
            _dominantMood = dominant;
            _dominantMoodEmoji = MoodService.getMoodEmoji(dominant);
          });
        }
      }

      // 2. New orbit connections added today
      final newConns = await Supabase.instance.client
          .from('user_orbits')
          .select('friend_id')
          .eq('user_id', userId)
          .gte('created_at', todayStart);

      if (mounted) {
        setState(() {
          _newConnectionsToday = (newConns as List).length;
          _timeActive = DateTime.now().difference(_sessionStart);
        });
      }
    } catch (e) {
      debugPrint('Error fetching vibe stats: $e');
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'Just started';
    if (d.inHours < 1) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Future<void> _fetchCurrentMood() async {
    try {
      final mood = await MoodService().getCurrentMood();
      if (mounted) {
        setState(() {
          _currentMood = mood;
        });
      }
    } catch (e) {
      debugPrint('Error fetching current mood: $e');
      // Default to 'Neutral' on error (already set)
    }
  }

  Future<void> _showMoodSelector() async {
    final selectedMood = await MoodSelector.show(context, _currentMood);
    if (selectedMood != null && selectedMood != _currentMood) {
      // Update mood in database
      final success = await MoodService().updateMood(selectedMood);
      if (success && mounted) {
        setState(() {
          _currentMood = selectedMood;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mood updated to $selectedMood ${MoodService.getMoodEmoji(selectedMood)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor      = isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText;
    final secondaryTextColor = isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext;
    final cardColor      = isDark ? AurbitWebTheme.darkCard    : AurbitWebTheme.lightCard;
    final borderColor    = isDark ? AurbitWebTheme.darkBorder  : AurbitWebTheme.lightBorder;

    final screenWidth = MediaQuery.of(context).size.width;
    // Desktop check: On web, always allow the web components to handle their own responsiveness
    final isDesktop = kIsWeb || screenWidth >= 1100;
    // Hide right sidebar if screen is too narrow for it
    final showRightSidebar = screenWidth >= 1100;

    final mobileAppBar = PreferredSize(
      preferredSize: const Size.fromHeight(100), // Height for Title + Mood row
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 16),
          child: Column(
            children: [
              // Top Row: Logo + Actions
              Row(
                children: [
                  Text(
                    'Aurbit',
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w900, // Extra bold
                      color: textColor,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  // Moon Button
                  _buildHeaderButton(
                    icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                    onTap: () {
                      ThemeService().toggleTheme();
                    },
                    context: context,
                  ),
                  const SizedBox(width: 8),
                  // Notification Button
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildHeaderButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationScreen(),
                              ),
                            );
                            // Parent polling validates count automatically
                          },
                          context: context,
                        ),
                        if (widget.notificationCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${widget.notificationCount}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  // Profile Button (Solid)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: ClipOval(
                        child: _userAvatarUrl != null
                            ? (_userAvatarUrl!.contains('.svg') || _userAvatarUrl!.contains('dicebear'))
                                ? SvgPicture.network(_userAvatarUrl!, fit: BoxFit.cover)
                                : Image.network(_userAvatarUrl!, fit: BoxFit.cover)
                            : Icon(Icons.person_outline, color: isDark ? Colors.black : Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Mood Row - Now clickable
              GestureDetector(
                onTap: _showMoodSelector,
                child: Row(
                  children: [
                    Text(
                      'Current mood: ',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _currentMood,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      MoodService.getMoodEmoji(_currentMood),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final feedContent = Column(
      children: [
        if (isDesktop) _buildWebFilterChips(isDark, borderColor, textColor),
        Expanded(
          child: _isLoading
            ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : AurbitWebTheme.accentPrimary))
            : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Space is quiet...',
                        style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPosts,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 24, 12, isDesktop ? 0 : 24, 24),
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) => SizedBox(height: isDesktop ? 10 : 16),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return FeedPostCard(
                        key: ValueKey(post['id']),
                        post: post,
                        onDelete: () {
                          setState(() => _posts.removeAt(index));
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        color: isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 740),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: feedContent,
                  ),
                ),
              ),
            ),
            if (showRightSidebar) _buildWebRightSidebar(context, isDark, borderColor, textColor),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: mobileAppBar,
      body: feedContent,
    );
  }

  // ── Filter chips (Trending / Latest / Global / Following) ──────────────────
  int _activeFilter = 0;

  Widget _buildWebFilterChips(bool isDark, Color borderColor, Color textColor) {
    final filters = ['Trending', 'Latest', 'Global', 'Following'];
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: List.generate(filters.length, (i) {
            final active = _activeFilter == i;
            return Padding(
              padding: EdgeInsets.only(right: i < filters.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () { setState(() => _activeFilter = i); _fetchPosts(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: active
                        ? AurbitWebTheme.accentPrimary
                        : (isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AurbitWebTheme.accentPrimary
                          : borderColor,
                    ),
                  ),
                  child: Text(
                    filters[i],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? Colors.white
                          : (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Sort bar (Hot / New / Top / Rising) ─────────────────────────────────────
  Widget _buildWebSortBar(bool isDark, Color borderColor, Color textColor) {
    final bgCard = isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _buildSortChip(Icons.local_fire_department_rounded, 'Hot', true, isDark, const Color(0xFFFF4500)),
          const SizedBox(width: 4),
          _buildSortChip(Icons.fiber_new_rounded, 'New', false, isDark, isDark ? Colors.grey[400]! : Colors.grey[700]!),
          const SizedBox(width: 4),
          _buildSortChip(Icons.trending_up_rounded, 'Top', false, isDark, isDark ? Colors.grey[400]! : Colors.grey[700]!),
          const SizedBox(width: 4),
          _buildSortChip(Icons.rocket_launch_outlined, 'Rising', false, isDark, isDark ? Colors.grey[400]! : Colors.grey[700]!),
        ],
      ),
    );
  }

  Widget _buildSortChip(IconData icon, String label, bool isActive, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: isActive ? color : (isDark ? Colors.grey[500] : Colors.grey[500])),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? color : (isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebRightSidebar(BuildContext context, bool isDark, Color borderColor, Color textColor) {
    final sidebarBg = isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightSidebar;
    final cardBg    = isDark ? AurbitWebTheme.darkCard    : Colors.white;
    final subColor  = isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext;
    final chipBg    = isDark ? const Color(0xFF252530)    : const Color(0xFFF1F3F5);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(left: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Mood Selector Widget ──────────────────────────────────
              _sidebarCard(
                borderColor: borderColor,
                cardBg: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How are you feeling?',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: textColor)),
                    const SizedBox(height: 14),
                    _buildMoodGrid(isDark, textColor, subColor),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Privacy Circles Widget ────────────────────────────────
              _sidebarCard(
                borderColor: borderColor,
                cardBg: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Privacy Circles',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: textColor)),
                        const Spacer(),
                        if (_selectedPrivacyCircle != null)
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedPrivacyCircle = null);
                              _fetchPosts();
                            },
                            child: Text('Clear',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AurbitWebTheme.accentPrimary,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildPrivacyCircleItem(
                      label: 'Private',
                      subtitle: 'Only you',
                      dotColor: const Color(0xFFEF4444),
                      trailingIcon: Icons.lock_outline_rounded,
                      isDark: isDark, textColor: textColor, subColor: subColor, chipBg: chipBg,
                      isSelected: _selectedPrivacyCircle == 'private',
                      onTap: () => _selectPrivacyCircle('Private'),
                    ),
                    const SizedBox(height: 8),
                    _buildPrivacyCircleItem(
                      label: 'Inner Orbit',
                      subtitle: 'Close friends',
                      dotColor: AurbitWebTheme.accentPrimary,
                      trailingIcon: Icons.group_outlined,
                      isDark: isDark, textColor: textColor, subColor: subColor, chipBg: chipBg,
                      isSelected: _selectedPrivacyCircle == 'inner_orbit',
                      onTap: () => _selectPrivacyCircle('Inner Orbit'),
                    ),
                    const SizedBox(height: 8),
                    _buildPrivacyCircleItem(
                      label: 'Outer Orbit',
                      subtitle: 'All connections',
                      dotColor: const Color(0xFF4ADE80),
                      trailingIcon: Icons.public_rounded,
                      isDark: isDark, textColor: textColor, subColor: subColor, chipBg: chipBg,
                      isSelected: _selectedPrivacyCircle == 'outer_orbit',
                      onTap: () => _selectPrivacyCircle('Outer Orbit'),
                    ),
                    const SizedBox(height: 8),
                    _buildPrivacyCircleItem(
                      label: 'Anonymous Public',
                      subtitle: 'Everyone',
                      dotColor: Colors.grey,
                      trailingIcon: Icons.person_off_outlined,
                      isDark: isDark, textColor: textColor, subColor: subColor, chipBg: chipBg,
                      isSelected: _selectedPrivacyCircle == 'anonymous_public',
                      onTap: () => _selectPrivacyCircle('Anonymous Public'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Today's Vibe Widget ───────────────────────────────────
              _sidebarCard(
                borderColor: borderColor,
                cardBg: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Today's Vibe",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: textColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AurbitWebTheme.accentPrimary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Live',
                              style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: AurbitWebTheme.accentPrimary,
                                  letterSpacing: 0.8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Time Active
                    _buildVibeStatRow(
                      icon: Icons.access_time_rounded,
                      iconColor: AurbitWebTheme.accentPrimary,
                      label: 'Time Active',
                      value: _formatDuration(_timeActive),
                      isDark: isDark, textColor: textColor, subColor: subColor,
                    ),
                    const SizedBox(height: 12),

                    // Dominant Mood
                    _buildVibeStatRow(
                      icon: Icons.mood_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Most Active Mood',
                      value: '$_dominantMoodEmoji $_dominantMood',
                      isDark: isDark, textColor: textColor, subColor: subColor,
                    ),
                    const SizedBox(height: 12),

                    // New Connections
                    _buildVibeStatRow(
                      icon: Icons.group_add_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: 'New Connections',
                      value: _newConnectionsToday == 0
                          ? 'None today'
                          : '+$_newConnectionsToday today',
                      isDark: isDark, textColor: textColor, subColor: subColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Footer note ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 15, color: AurbitWebTheme.accentPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No likes. No followers. Just authentic connections at your own pace.',
                        style: GoogleFonts.inter(fontSize: 11, color: subColor, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sidebar helper: generic card container ─────────────────────────────────
  Widget _sidebarCard({required Widget child, required Color borderColor, required Color cardBg}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  // ── Mood 4-grid ─────────────────────────────────────────────────────────────
  final _moods = [
    ('Happy',    Icons.mood_rounded),
    ('Peaceful', Icons.sentiment_satisfied_rounded),
    ('Grateful', Icons.auto_awesome_rounded),
    ('Bored',   Icons.nights_stay_rounded),
  ];

  Widget _buildMoodGrid(bool isDark, Color textColor, Color subColor) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: _moods.map((m) {
        final label = m.$1;
        final icon  = m.$2;
        final isActive = _currentMood == label;
        return GestureDetector(
          onTap: () async {
            final old = _currentMood;
            setState(() => _currentMood = label);
            final ok = await MoodService().updateMood(label);
            if (!ok && mounted) setState(() => _currentMood = old);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isActive
                  ? AurbitWebTheme.accentPrimary.withOpacity(isDark ? 0.25 : 0.10)
                  : (isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? AurbitWebTheme.accentPrimary.withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20,
                    color: isActive ? AurbitWebTheme.accentPrimary : subColor),
                const SizedBox(height: 4),
                Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AurbitWebTheme.accentPrimary : subColor,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Privacy circle row ───────────────────────────────────────────────────────
  Widget _buildPrivacyCircleItem({
    required String label,
    required String subtitle,
    required Color dotColor,
    required bool isDark,
    required Color textColor,
    required Color subColor,
    required Color chipBg,
    required bool isSelected,
    IconData? trailingIcon,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AurbitWebTheme.accentPrimary.withOpacity(isDark ? 0.18 : 0.08)
              : chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AurbitWebTheme.accentPrimary.withOpacity(0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: isSelected ? AurbitWebTheme.accentPrimary : textColor)),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: subColor)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 15, color: AurbitWebTheme.accentPrimary)
            else if (trailingIcon != null)
              Icon(trailingIcon, size: 15, color: subColor),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeBar(String label, String value, double percent, bool isDark, Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: subColor, letterSpacing: 0.8)),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: subColor)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                    color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0)),
                FractionallySizedBox(
                  widthFactor: percent,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AurbitWebTheme.accentPrimary.withOpacity(0.8),
                          AurbitWebTheme.accentPrimary,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: isDark ? Colors.white : Colors.grey[800], size: 22),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildVibeStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    required Color textColor,
    required Color subColor,
  }) {
    final rowBg = isDark ? const Color(0xFF252530) : const Color(0xFFF8F9FB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: subColor, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
