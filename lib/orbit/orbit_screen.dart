import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/theme_service.dart';
import '../profile/profile_screen.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/orbit_member_actions_sheet.dart';
import '../notifications/notification_screen.dart';
import '../models/user_orbit.dart' as model;
import '../services/orbit_service.dart';
import '../services/notification_service.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class OrbitScreen extends StatefulWidget {
  final int notificationCount;
  const OrbitScreen({super.key, this.notificationCount = 0});

  @override
  State<OrbitScreen> createState() => _OrbitScreenState();
}

enum OrbitType { inner, outer }

class OrbitFriend {
  final String id;
  final String name;
  final String? avatarUrl; 
  final String colorHex;
  final String moodEmoji;
  final String moodString; // Added to store original mood text
  OrbitType type;
  double angle; 
  final double speed; 

  OrbitFriend({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.colorHex,
    required this.moodEmoji,
    required this.moodString,
    required this.type,
    required this.angle,
    required this.speed,
  });
}

class _OrbitScreenState extends State<OrbitScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _userAvatarUrl;
  String? _userMoodEmoji;
  final OrbitService _orbitService = OrbitService(); // Service instance

  final List<OrbitFriend> _friends = [];
  bool _isLoading = true;
  
  // Username visibility tracking
  String? _visibleUsernameId;
  Timer? _usernameTimer;

  // ── Today's Vibe state ─────────────────────────────────────────────────────
  late final DateTime _sessionStart;
  Timer? _vibeTimer;
  Duration _timeActive = Duration.zero;
  String _dominantMood = '—';
  String _dominantMoodEmoji = '😐';
  int _newConnectionsToday = 0;


  // Helper to switch to better looking avatar pack and fix SVG glitches
  String? _getThemeAvatarUrl(String? url) {
    if (url == null) return null;
    // Switch to 'notionists' pack for a cleaner look and to fix SVG artifacts
    if (url.contains('dicebear.com')) {
      final uri = Uri.parse(url);
      final pathSegments = List<String>.from(uri.pathSegments);
      if (pathSegments.length >= 2 && pathSegments[0] == '7.x') {
        pathSegments[1] = 'notionists'; // New Image Pack
        return uri.replace(pathSegments: pathSegments).toString();
      }
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _fetchUserAvatar();
    _fetchCurrentUserMood();
    _fetchOrbitFriends();
    _fetchVibeStats();

    _sessionStart = DateTime.now();
    _vibeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _timeActive = DateTime.now().difference(_sessionStart));
    });

    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
      
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          for (var friend in _friends) {
            friend.angle += friend.speed;
            if (friend.angle > 2 * pi) {
              friend.angle -= 2 * pi;
            }
          }
        });
      }
    });
  }



  Future<void> _fetchOrbitFriends() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch saved orbit status (user_orbits table)
      final List<dynamic> savedOrbitData = await Supabase.instance.client
          .from('user_orbits')
          .select('friend_id, orbit_type')
          .eq('user_id', userId);

      final Map<String, OrbitType> savedOrbitMap = {};
      final List<String> friendIds = [];
      
      for (var item in savedOrbitData) {
        final fId = item['friend_id']?.toString() ?? '';
        final layer = item['orbit_type']?.toString();
        if (fId.isNotEmpty) {
           savedOrbitMap[fId] = layer == 'inner' ? OrbitType.inner : OrbitType.outer;
           friendIds.add(fId);
        }
      }

      if (friendIds.isEmpty) {
        if (mounted) {
          setState(() {
            _friends.clear();
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch profiles only for friends
      final List<dynamic> profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, current_mood')
          .filter('id', 'in', friendIds);

      final random = Random();
      final List<OrbitFriend> newFriends = [];

      for (var i = 0; i < profiles.length; i++) {
        final p = profiles[i];
        final pid = p['id'].toString();
        final username = p['username']?.toString() ?? 'User';
        // Apply theme avatar transformation
        final avatarUrl = _getThemeAvatarUrl(p['avatar_url']?.toString());
        final mood = (p['current_mood'] as String?) ?? 'Happy'; 
        
        String emoji = '😊';
        switch (mood) {
          case 'Happy': emoji = '😊'; break;
          case 'Sad': emoji = '😢'; break;
          case 'Tired': emoji = '😴'; break;
          case 'Irritated': emoji = '😠'; break;
          case 'Lonely': emoji = '☁️'; break;
          case 'Bored': emoji = '😐'; break;
          case 'Peaceful': emoji = '😌'; break;
          case 'Grateful': emoji = '🙏'; break;
          default: emoji = '😊';
        }

        final colors = ['FF7043', '7E57C2', 'FFA726', 'EF5350', 'EC407A', '5C6BC0', '26C6DA', '43A047'];
        final color = colors[random.nextInt(colors.length)];

        // Force type from saved map since we only fetched friends
        OrbitType type = savedOrbitMap[pid] ?? OrbitType.outer;

        final angle = random.nextDouble() * 2 * pi;

        newFriends.add(OrbitFriend(
          id: pid,
          name: username,
          avatarUrl: avatarUrl,
          colorHex: color,
          moodEmoji: emoji,
          moodString: mood,
          type: type,
          angle: angle,
          speed: 0.001 + random.nextDouble() * 0.001,
        ));
      }

      if (mounted) {
        setState(() {
          _friends.clear();
          _friends.addAll(newFriends);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFriendOrbitStatus(String friendId, OrbitType type) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('user_orbits').upsert({
        'user_id': userId,
        'friend_id': friendId,
        'orbit_type': type == OrbitType.inner ? 'inner' : 'outer',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, friend_id');
    } catch (e) {
      debugPrint('Error updating orbit status: $e');
    }
  }

  Future<void> _fetchCurrentUserMood() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('mood_logs')
          .select('mood')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted && data != null) {
        final mood = data['mood']?.toString();
        if (mood != null) {
          String emoji = '😊';
          switch (mood) {
            case 'Happy': emoji = '😊'; break;
            case 'Sad': emoji = '😢'; break;
            case 'Tired': emoji = '😴'; break;
            case 'Irritated': emoji = '😠'; break;
            case 'Lonely': emoji = '☁️'; break;
            case 'Bored': emoji = '😐'; break;
            case 'Peaceful': emoji = '😌'; break;
            case 'Grateful': emoji = '🙏'; break;
            default: emoji = '😊';
          }
           setState(() {
             _userMoodEmoji = emoji;
           });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user mood: $e');
    }
  }

  Future<void> _fetchUserAvatar() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', userId)
            .single();
        if (mounted && data['avatar_url'] != null) {
          setState(() {
            _userAvatarUrl = _getThemeAvatarUrl(data['avatar_url'].toString());
          });
        }
      } catch (e) { /* ignore */ }
    }
  }

  void _showMemberActions(OrbitFriend friend) {
    // Construct dummy UserOrbit for the sheet
    final dummyOrbitUser = model.UserOrbit(
      id: '', // Dummy ID
      userId: Supabase.instance.client.auth.currentUser?.id ?? '',
      friendId: friend.id,
      orbitType: friend.type == OrbitType.inner ? 'inner' : 'outer',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      friendUsername: friend.name,
      friendAvatarUrl: friend.avatarUrl,
      friendCurrentMood: friend.moodString, 
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => OrbitMemberActionsSheet(
        orbitUser: dummyOrbitUser,
        onRemove: () async {
           // Call service logic to remove from DB
           try {
             await _orbitService.removeFromOrbit(friend.id);
             // Update local state
             if (mounted) {
               setState(() {
                 _friends.removeWhere((f) => f.id == friend.id);
               });
             }
           } catch (e) {
             debugPrint('Error removing friend: $e');
           }
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameTimer?.cancel();
    _vibeTimer?.cancel();
    super.dispose();
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
            _dominantMoodEmoji = _getMoodEmojiForVibe(dominant);
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

  String _getMoodEmojiForVibe(String mood) {
    switch (mood) {
      case 'Happy': return '🤩';
      case 'Sad': return '😢';
      case 'Tired': return '😴';
      case 'Irritated': return '😤';
      case 'Lonely': return '😶‍🌫️';
      case 'Bored': return '😑';
      case 'Peaceful': return '😌';
      case 'Grateful': return '🙏';
      default: return '😐';
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'Just started';
    if (d.inHours < 1) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb  = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final showRightSidebar = screenWidth >= 1100;

    final textColor         = isWeb ? (isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText)    : (isDark ? Colors.white : Colors.black);
    final secondaryTextColor = isWeb ? (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext) : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    final innerCount = _friends.where((f) => f.type == OrbitType.inner).length;
    final outerCount = _friends.where((f) => f.type == OrbitType.outer).length;

    return Scaffold(
      backgroundColor: isWeb
          ? (isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg)
          : Theme.of(context).scaffoldBackgroundColor,
      body: isWeb ? _buildWebLayout(context, isDark, textColor, secondaryTextColor, showRightSidebar) : _buildMobileBody(context, isDark, textColor, secondaryTextColor, innerCount, outerCount),
    );
  }

  Widget _buildMobileBody(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, int innerCount, int outerCount) {
    return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              onRefresh: _fetchOrbitFriends,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                   height: constraints.maxHeight,
                   child: Column(
                    children: [
                      Expanded(child: _buildOrbitMainContent(isDark, textColor, secondaryTextColor, innerCount, outerCount)),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      );
  }

  Widget _buildWebLayout(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, bool showRightSidebar) {
    final screenWidth = MediaQuery.of(context).size.width;
    final borderColor = isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder;
    final innerCount = _friends.where((f) => f.type == OrbitType.inner).length;
    final outerCount = _friends.where((f) => f.type == OrbitType.outer).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Center)
        Expanded(
          flex: 8,
          child: Column(
            children: [
              if (screenWidth <= 800)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AurbitWebTheme.darkTopbar : AurbitWebTheme.lightTopbar,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text('Orbit', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                    ],
                  ),
                ),
              Expanded(child: _buildOrbitMainContent(isDark, textColor, secondaryTextColor, innerCount, outerCount)),
            ],
          ),
        ),


        // Right Sidebar
        if (showRightSidebar)
          Container(
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
                  _sidebarCard(
                    'Today\'s Vibe',
                    'Live session stats',
                    isDark, textColor, secondaryTextColor, borderColor,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildVibeStatRow(
                          icon: Icons.access_time_rounded,
                          iconColor: AurbitWebTheme.accentPrimary,
                          label: 'Time Active',
                          value: _formatDuration(_timeActive),
                          isDark: isDark, textColor: textColor, subColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 12),
                        _buildVibeStatRow(
                          icon: Icons.mood_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Most Active Mood',
                          value: '$_dominantMoodEmoji $_dominantMood',
                          isDark: isDark, textColor: textColor, subColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 12),
                        _buildVibeStatRow(
                          icon: Icons.group_add_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'New Connections',
                          value: _newConnectionsToday == 0 ? 'None today' : '+$_newConnectionsToday today',
                          isDark: isDark, textColor: textColor, subColor: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sidebarCard('Orbit Stats', 'Your inner circle is growing! You have $innerCount close connections.', isDark, textColor, secondaryTextColor, borderColor),
                  const SizedBox(height: 16),
                  _sidebarCard('Mindful Connections', 'Mindful interactions are key to a healthy orbit. Keep it positive!', isDark, textColor, secondaryTextColor, borderColor),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrbitMainContent(bool isDark, Color textColor, Color secondaryTextColor, int innerCount, int outerCount) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Orbit',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Drag friends to shift orbits',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildOrbitMiniStats('Inner', innerCount, isDark),
                  const SizedBox(width: 12),
                  _buildOrbitMiniStats('Outer', outerCount, isDark),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildOrbitVisual(isDark),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildOrbitMiniStats(String label, int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(width: 6),
          Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AurbitWebTheme.accentPrimary)),
        ],
      ),
    );
  }

  Widget _buildOrbitVisual(bool isDark) {
    return LayoutBuilder(
      builder: (context, constr) {
        final center = Offset(constr.maxWidth / 2, constr.maxHeight / 2);
        // Maximize radius but leave just enough room for the friend avatars (48px / 2 = 24px)
        final maxRadius = (min(constr.maxWidth, constr.maxHeight) / 2) - 30; 
        final innerRadius = maxRadius * 0.45;
        final outerRadius = maxRadius; 


        return DragTarget<OrbitFriend>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) {
            final dropPosition = details.offset;
            final renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(dropPosition);

            final dx = localPosition.dx - center.dx;
            final dy = localPosition.dy - center.dy;
            final distance = sqrt(dx*dx + dy*dy);
            final boundary = (innerRadius + outerRadius) / 2;

            setState(() {
               final friendIndex = _friends.indexWhere((f) => f.id == details.data.id);
               if(friendIndex != -1) {
                 _friends[friendIndex].type = distance < boundary ? OrbitType.inner : OrbitType.outer;
                 _friends[friendIndex].angle = atan2(dy, dx);
                 _updateFriendOrbitStatus(_friends[friendIndex].id, _friends[friendIndex].type);
               }
            });
          },
          builder: (context, candidateData, rejectedData) {
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(constr.maxWidth, constr.maxHeight),
                  painter: OrbitPathPainter(
                    innerRadius: innerRadius,
                    outerRadius: outerRadius,
                    isDark: isDark,
                  ),
                ),

                // Me
                Container(
                   width: 120,
                   height: 120,
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                     border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), width: 6),

                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.1),
                         blurRadius: 20,
                         spreadRadius: 5,
                       )
                     ]
                   ),
                   child: GestureDetector(
                     onTap: () {
                       Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                     },
                     child: Stack(
                       alignment: Alignment.center,
                       clipBehavior: Clip.none,
                       children: [
                         ClipOval(
                            clipBehavior: Clip.hardEdge,
                            child: _userAvatarUrl != null
                                ? (_userAvatarUrl!.contains('.svg') || _userAvatarUrl!.contains('dicebear'))
                                    ? SvgPicture.network(
                                        _userAvatarUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        excludeFromSemantics: true,
                                      )
                                    : Image.network(
                                        _userAvatarUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                : Icon(
                                    Icons.person,
                                    size: 50,
                                    color: isDark ? Colors.grey[700] : Colors.grey,
                                  ),
                          ),
                         // User Mood Emoji
                         if (_userMoodEmoji != null)
                           Positioned(
                             right: 0,
                             top: 0,
                             child: Container(
                               width: 32,
                               height: 32,
                               decoration: BoxDecoration(
                                 color: isDark ? Colors.grey[800] : Colors.white,
                                 shape: BoxShape.circle,
                                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
                               ),
                               alignment: Alignment.center,
                               child: Text(_userMoodEmoji!, style: const TextStyle(fontSize: 18)),
                             ),
                           ),

                         Positioned(
                            bottom: -20,
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                               decoration: BoxDecoration(
                                 color: isDark ? Colors.grey[800] : Colors.white,
                                 borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                               ),
                               child: Text('You', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            )
                         )
                       ],
                     ),
                   ),
                ),

                // Friends
                ..._friends.map((friend) {
                   final r = friend.type == OrbitType.inner ? innerRadius : outerRadius;
                   final x = center.dx + r * cos(friend.angle) - 24;
                   final y = center.dy + r * sin(friend.angle) - 24;

                   return Positioned(
                     left: x,
                     top: y,
                     child: Draggable<OrbitFriend>(
                       data: friend,
                       feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.2,
                            child: _buildFriendAvatarOnly(friend, context)
                          ),
                       ),
                       childWhenDragging: Opacity(opacity: 0.3, child: _buildFriendWidget(friend, 1.0, context)),
                       child: GestureDetector(
                          onTap: () => _showUsernameTemporarily(friend.id),
                          onLongPress: () => _showMemberActions(friend),
                         child: _buildFriendWidget(friend, 1.0, context),
                       ),
                     ),
                   );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sidebarCard(String title, String content, bool isDark, Color textColor, Color secondaryTextColor, Color borderColor, {Widget? child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.outfit(fontSize: 13, color: secondaryTextColor, height: 1.4)),
          if (child != null) child,
        ],
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: subColor, fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarOrbitTips(Color textColor, Color secondaryTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ORBIT TIPS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: secondaryTextColor, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        ...['Drag friends to switch orbits', 'Tap to see their name', 'Long press for more actions'].map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: AurbitWebTheme.accentPrimary),
              const SizedBox(width: 8),
              Expanded(child: Text(tip, style: GoogleFonts.inter(fontSize: 12, color: textColor))),
            ],
          ),
        )),
      ],
    );
  }

  // Simplified avatar helper for drag feedback
  Widget _buildFriendAvatarOnly(OrbitFriend friend, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(int.parse('0xFF${friend.colorHex}')),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
                  ? (friend.avatarUrl!.contains('.svg') || friend.avatarUrl!.contains('dicebear'))
                      ? SvgPicture.network(
                          friend.avatarUrl!,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          friend.avatarUrl!,
                          fit: BoxFit.cover,
                        )
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              ),
              child: Center(
                child: Text(friend.moodEmoji, style: const TextStyle(fontSize: 14)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFriendWidget(OrbitFriend friend, double scale, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(int.parse('0xFF${friend.colorHex}')),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
                      ? (friend.avatarUrl!.contains('.svg') || friend.avatarUrl!.contains('dicebear'))
                          ? SvgPicture.network(
                              friend.avatarUrl!,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            )
                          : Image.network(
                              friend.avatarUrl!,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            )
                      : const SizedBox.shrink(),
                ),
              ),
               Positioned(
                 right: -4,
                 top: -4,
                 child: Container(
                   width: 20,
                   height: 20,
                   decoration: BoxDecoration(
                     color: isDark ? Colors.grey[800] : Colors.white,
                     shape: BoxShape.circle,
                     boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
                   ),
                   alignment: Alignment.center,
                   child: Text(friend.moodEmoji, style: const TextStyle(fontSize: 12)),
                 ),
               )
            ],
          ),
          const SizedBox(height: 4),
          if (_visibleUsernameId == friend.id)
            Text(
              friend.name,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Aurbit',
            style: GoogleFonts.outfit(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          Row(
            children: [
               _buildHeaderButton(
                 icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                 onTap: () => ThemeService().toggleTheme(),
                 context: context,
               ),
               const SizedBox(width: 8),
               Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildHeaderButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                      },
                      context: context
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
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb  = kIsWeb;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isWeb
            ? (isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard)
            : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: isWeb
              ? (isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder)
              : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: isDark ? Colors.white : Colors.grey[800], size: 22),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildOrbitCard(String title, String count, String subtitle, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Text(count, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.outfit(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 10)),
        ],
      ),
    );
  }

  /// Show username for a friend for 5 seconds
  void _showUsernameTemporarily(String friendId) {
    // Cancel any existing timer
    _usernameTimer?.cancel();
    
    setState(() {
      _visibleUsernameId = friendId;
    });

    // Hide after 5 seconds
    _usernameTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _visibleUsernameId = null;
        });
      }
    });
  }
}

class OrbitPathPainter extends CustomPainter {
  final double innerRadius;
  final double outerRadius;
  final bool isDark;

  OrbitPathPainter({required this.innerRadius, required this.outerRadius, this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawDashedCircle(canvas, paint, center, innerRadius);
    
    // Outer orbit slightly lower opacity but still highly visible
    paint.color = isDark ? Colors.blue.withOpacity(0.4) : Colors.blue.withOpacity(0.3);
    _drawDashedCircle(canvas, paint, center, outerRadius);

    // Add stronger glow circles (non-dashed)
    final glowPaint = Paint()
      ..color = isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, innerRadius, glowPaint);
    canvas.drawCircle(center, outerRadius, glowPaint);
  }

  void _drawDashedCircle(Canvas canvas, Paint paint, Offset center, double radius) {
    const double dashWidth = 3;
    const double dashSpace = 4;
    double currentAngle = 0;
    while (currentAngle < 2 * pi) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        dashWidth / radius,
        false,
        paint,
      );
      currentAngle += (dashWidth + dashSpace) / radius;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}
