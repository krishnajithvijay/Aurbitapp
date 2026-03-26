import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/community_service.dart';
import '../services/community_admin_service.dart';
import '../theme/theme_service.dart';
import '../profile/profile_screen.dart';
import '../services/notification_service.dart';
import '../notifications/notification_screen.dart';
import 'create_community_post_screen.dart';
import 'community_post_detail_screen.dart';
import 'community_members_screen.dart';
import 'community_settings_screen.dart';
import 'package:flutter/foundation.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens
import '../widgets/verified_badge.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/link_preview_card.dart';
import '../services/link_preview_service.dart';

class CommunityFeedScreen extends StatefulWidget {
  final Map<String, dynamic> community;

  const CommunityFeedScreen({
    super.key,
    required this.community,
  });

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final CommunityService _communityService = CommunityService();
  final CommunityAdminService _adminService = CommunityAdminService();
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isMember = false;
  bool _isAdmin = false;
  int _memberCount = 0;
  int _activeCount = 0;
  int _notificationCount = 0;
  String? _userAvatarUrl;

  late final RealtimeChannel _postsChannel;
  late final RealtimeChannel _presenceChannel;

  @override
  void initState() {
    super.initState();
    _fetchUserAvatar();
    _checkMembership();
    _checkAdminStatus();
    _fetchPosts();
    _fetchMemberCount();
    _fetchNotificationCount();
    _subscribeToPosts();
    _subscribeToPresence();
  }

  @override
  void dispose() {
    _postsChannel.unsubscribe();
    _presenceChannel.unsubscribe();
    super.dispose();
  }

  void _subscribeToPresence() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _presenceChannel = _supabase.channel('presence:community:${widget.community['id']}', opts: const RealtimeChannelConfig(key: 'community_presence'));
    
    _presenceChannel
      .onPresenceSync((payload) {
        if (!mounted) return;
        final presenceState = _presenceChannel.presenceState();
        setState(() {
          // Count unique user IDs in presence state
          final uniqueUsers = <String>{};
          // The compiler indicates presenceState is an Iterable<SinglePresenceState> (List of Lists), or similar.
          // We use dynamic iteration to support both List and Map.values scenarios safely at runtime if types are ambiguous.
          final dynamic state = presenceState;
          
          if (state is Map) {
            for (var presences in state.values) {
               if (presences is List) {
                 for (var presence in presences) {
                   if (presence.payload != null && presence.payload['user_id'] != null) {
                      uniqueUsers.add(presence.payload['user_id']);
                   }
                 }
               }
            }
          } else if (state is List || state is Iterable) {
             for (var presences in state) {
               // presences usually is generic List<Presence> (SinglePresenceState)
               if (presences is List) {
                  for (var presence in presences) {
                     if (presence.payload != null && presence.payload['user_id'] != null) {
                        uniqueUsers.add(presence.payload['user_id']);
                     }
                  }
               }
             }
          }
          
          _activeCount = uniqueUsers.length;
          // Ensure at least 1 (me) if connected
          if (_activeCount == 0) _activeCount = 1;
        });
      })
      .subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _presenceChannel.track({'user_id': userId, 'online_at': DateTime.now().toIso8601String()});
        }
      });
  }

  void _subscribeToPosts() {
    _postsChannel = _supabase
        .channel('community_posts:${widget.community['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: widget.community['id']?.toString(),
          ),
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newPostId = payload.newRecord['id'];
              if (newPostId != null) {
                await _fetchSinglePost(newPostId);
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
               final updatedPost = payload.newRecord;
               if (mounted) {
                 setState(() {
                   final index = _posts.indexWhere((p) => p['id'] == updatedPost['id']);
                   if (index != -1) {
                     final existing = _posts[index];
                     _posts[index] = {
                       ...existing,
                       'content': updatedPost['content'],
                       'mood': updatedPost['mood'],
                       'moodEmoji': _getMoodEmoji(updatedPost['mood']),
                     };
                   }
                 });
               }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
               final deletedId = payload.oldRecord['id'];
               if (mounted && deletedId != null) {
                 setState(() {
                   _posts.removeWhere((p) => p['id'] == deletedId);
                 });
               }
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchSinglePost(String postId) async {
    try {
      final response = await _supabase
          .from('community_posts')
          .select('''
            *,
            profile:user_id(id, username, avatar_url, is_verified)
          ''')
          .eq('id', postId)
          .single();

      final post = response;
      final profile = post['profile'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          final isAnonymous = post['is_anonymous'] ?? false;
          final newPostMap = {
            'id': post['id'],
            'user_id': post['user_id'],
            'username': isAnonymous ? 'Anonymous' : (profile?['username'] ?? 'User'),
            'avatar_url': isAnonymous ? null : profile?['avatar_url'],
            'is_verified': (profile?['is_verified'] as bool?) ?? false,
            'timeAgo': 'Just now',
            'mood': post['mood'] ?? 'Neutral',
            'moodEmoji': _getMoodEmoji(post['mood']),
            'content': post['content'] ?? '',
            'community_username': widget.community['username'] ?? 'space',
            'relateCount': 0,
            'supportCount': 0,
          };
          
          _posts.insert(0, newPostMap);
        });
      }
    } catch (e) {
      debugPrint('Error fetching new post: $e');
    }
  }

  Future<void> _fetchUserAvatar() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', userId)
            .maybeSingle(); 
            
        if (mounted && data != null && data['avatar_url'] != null) {
          setState(() {
            _userAvatarUrl = data['avatar_url'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching avatar: $e');
      }
    }
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final count = await NotificationService().getUnreadCount();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  Future<void> _checkMembership() async {
    final isMember = await _communityService.isMember(widget.community['id']);
    if (mounted) {
      setState(() => _isMember = isMember);
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin(widget.community['id']);
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _fetchMemberCount() async {
    try {
      final count = await _supabase
          .from('community_members')
          .count()
          .eq('community_id', widget.community['id']);

      if (mounted) {
        setState(() {
          _memberCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error fetching member count: $e');
    }
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('community_posts')
          .select('''
            *,
            profile:user_id(id, username, avatar_url, is_verified)
          ''')
          .eq('community_id', widget.community['id'])
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(data.map((post) {
            final profile = post['profile'] as Map<String, dynamic>?;
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

            return {
              'id': post['id'],
              'user_id': post['user_id'],
              'username': isAnonymous ? 'Anonymous' : (profile?['username'] ?? 'User'),
              'avatar_url': isAnonymous ? null : profile?['avatar_url'],
              'is_verified': (profile?['is_verified'] as bool?) ?? false,
              'timeAgo': timeAgo,
              'mood': post['mood'] ?? 'Neutral',
              'moodEmoji': _getMoodEmoji(post['mood']),
              'content': post['content'] ?? '',
              'community_username': widget.community['username'] ?? 'space',
              'relateCount': 0,
              'supportCount': 0,
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

  String _getMoodEmoji(String? mood) {
    switch (mood) {
      case 'Happy': return '🤩';
      case 'Sad': return '😢';
      case 'Tired': return '😴';
      case 'Irritated': return '😤';
      case 'Lonely': return '😶🌫️';
      case 'Bored': return '😑';
      case 'Peaceful': return '😌';
      case 'Grateful': return '🙏';
      default: return '😐';
    }
  }

  Future<void> _handleJoinCommunity() async {
    final result = await _communityService.joinCommunity(widget.community['id']);
    
    if (mounted) {
      if (result['success'] == true) {
        setState(() => _isMember = true);
        await _fetchMemberCount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${widget.community['name']}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result['banned'] == true) {
        _showBanWarningDialog(
          daysRemaining: result['banInfo']?['days_remaining'] ?? 0,
          reason: result['banInfo']?['reason'],
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to join community'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBanWarningDialog({required int daysRemaining, String? reason}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You\'re Banned',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$daysRemaining days remaining',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Reason:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.red[200] : Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.red[300] : Colors.red[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You cannot join this community until your ban expires.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Understood',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveCommunity() async {
    final userId = _supabase.auth.currentUser?.id;
    final createdBy = widget.community['created_by'];
    
    if (userId != null && createdBy == userId) {
       await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Leave Community'),
          content: const Text('As the creator of this community, you cannot leave it. You can only delete the community from the settings menu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldLeave = await CommunityService.showLeaveCommunityDialog(
      context,
      widget.community['name'],
    );

    if (shouldLeave && mounted) {
      final success = await _communityService.leaveCommunity(widget.community['id']);
      if (success && mounted) {
        setState(() => _isMember = false);
        await _fetchMemberCount();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Left ${widget.community['name']}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _createPost() async {
    if (!_isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join the community to create posts'),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCommunityPostScreen(
          community: widget.community,
        ),
      ),
    );

    if (result == true) {
      _fetchPosts();
    }
  }

  Future<void> _deletePost(String postId, String postUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null || postUserId != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own posts')),
      );
      return;
    }

    final shouldDelete = await _showDeleteDialog(
      context,
      'Delete Post?',
      'Are you sure you want to delete this post? This action cannot be undone.',
    );

    if (!shouldDelete) return;

    try {
      await _supabase
          .from('community_posts')
          .delete()
          .eq('id', postId);

      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p['id'] == postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  Future<bool> _showDeleteDialog(BuildContext context, String title, String message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: secondaryTextColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb = kIsWeb;
    final accent = AurbitWebTheme.accentPrimary;

    final textColor = isWeb ? (isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText) : (isDark ? Colors.white : Colors.black);
    final secondaryTextColor = isWeb ? (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext) : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
    final cardColor = isWeb ? (isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard) : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isWeb ? (isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder) : (isDark ? Colors.grey[800]! : Colors.grey[200]!);

    return Scaffold(
      backgroundColor: isWeb ? (isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg) : Theme.of(context).scaffoldBackgroundColor,
      body: isWeb 
          ? _buildWebLayout(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, accent) 
          : _buildMobileBody(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, accent),
      floatingActionButton: _isMember
          ? FloatingActionButton(
              onPressed: _createPost,
              backgroundColor: isDark ? Colors.white : Colors.black,
              child: Icon(
                Icons.add,
                color: isDark ? Colors.black : Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildMobileBody(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, Color cardColor, Color borderColor, Color accent) {
    return SafeArea(
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
              child: Column(
                children: [
                  // Top Row: Community Name + Actions
                  Row(
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.community['name'] ?? 'Community',
                              style: GoogleFonts.inter(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (widget.community['bio'] != null && 
                                widget.community['bio'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.community['bio'],
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: secondaryTextColor,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Members Button (shows for all members)
                      if (_isMember)
                        _buildHeaderButton(
                          icon: Icons.people_outline_rounded,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommunityMembersScreen(
                                  communityId: widget.community['id'],
                                  communityName: widget.community['name'],
                                  isAdmin: _isAdmin,
                                ),
                              ),
                            );
                            _fetchMemberCount();
                          },
                          context: context,
                        ),
                      if (_isMember) const SizedBox(width: 4),
                      // Settings Button (admin only)
                      if (_isAdmin)
                        _buildHeaderButton(
                          icon: Icons.settings_outlined,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommunitySettingsScreen(
                                  communityId: widget.community['id'],
                                  currentName: widget.community['name'],
                                  currentBio: widget.community['bio'],
                                ),
                              ),
                            );
                            if (result == true && mounted) {
                              // Re-fetch community details to update UI
                              final updated = await _supabase
                                  .from('communities')
                                  .select()
                                  .eq('id', widget.community['id'])
                                  .single();
                              setState(() {
                                widget.community['name'] = updated['name'];
                                widget.community['bio'] = updated['bio'];
                              });
                            }
                          },
                          context: context,
                        ),
                      if (_isAdmin) const SizedBox(width: 4),
                      // Theme Toggle
                      _buildHeaderButton(
                        icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                        onTap: () {
                          ThemeService().toggleTheme();
                        },
                        context: context,
                      ),
                      const SizedBox(width: 4),
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
                              _fetchNotificationCount();
                            },
                            context: context,
                          ),
                          if (_notificationCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$_notificationCount',
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
                      const SizedBox(width: 4),
                      // Profile Button
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

                  // Community Info Row
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_memberCount members',
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.circle,
                        size: 4,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_activeCount active',
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // Join/Leave Button
                      TextButton(
                        onPressed: _isMember ? _handleLeaveCommunity : _handleJoinCommunity,
                        style: TextButton.styleFrom(
                          backgroundColor: _isMember
                              ? Colors.transparent
                              : (isDark ? Colors.white : Colors.black),
                          foregroundColor: _isMember
                              ? secondaryTextColor
                              : (isDark ? Colors.black : Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: _isMember
                                ? BorderSide(color: borderColor)
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          _isMember ? 'Leave' : 'Join',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
                  : _posts.isEmpty 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_outlined, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _isMember ? 'No posts yet. Be the first!' : 'Join to see posts',
                                style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 16),
                              ),
                              if (_isMember) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _createPost,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    'Create Post',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ) 
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _fetchPosts();
                            await _fetchMemberCount();
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: _posts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final post = _posts[index];
                              return _buildPostCard(post, isDark, cardColor, borderColor, textColor, secondaryTextColor);
                            },
                          ),
                        ),
            ),
          ],
        ),
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

  Widget _buildPostCard(
    Map<String, dynamic> post,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color? secondaryTextColor,
  ) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final isOwnPost = currentUserId == post['user_id'];
    final rawContent = post['content']?.toString() ?? '';
    final displayContent = LinkPreviewService.stripUrls(rawContent);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityPostDetailScreen(post: post),
          ),
        ).then((_) => _fetchPosts()); 
      },
      onLongPress: isOwnPost ? () => _deletePost(post['id'], post['user_id']) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    if (post['is_anonymous'] == true || post['username'] == 'Anonymous') return;

                    final userId = post['user_id'];
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: userId),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: post['avatar_url'] != null
                              ? (post['avatar_url'].toString().contains('.svg') || post['avatar_url'].toString().contains('dicebear'))
                                  ? SvgPicture.network(post['avatar_url'], fit: BoxFit.cover)
                                  : Image.network(post['avatar_url'], fit: BoxFit.cover)
                              : Icon(Icons.person_outline, color: isDark ? Colors.white : Colors.grey[800], size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UsernameWithBadge(
                            username: post['username'],
                            isVerified: post['is_verified'] ?? false,
                            textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor,
                            ),
                            badgeSize: 14,
                          ),
                          Text(
                            post['timeAgo'],
                            style: GoogleFonts.inter(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(post['moodEmoji'], style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        post['mood'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              displayContent,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.4,
                color: textColor,
              ).copyWith(
                fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
              ),
            ),
            Builder(
              builder: (_) {
                final url = LinkPreviewService.extractUrl(rawContent);
                if (url == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: LinkPreviewCard(
                    url: url,
                    isDark: isDark,
                    borderColor: borderColor,
                    cardBg: isDark ? const Color(0xFF1A1A24) : const Color(0xFFF8FAFC),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                _buildActionChip(
                  'I relate', 
                  post['relateCount'], 
                  context,
                  isActive: false,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _buildActionChip(
                  "You're not alone", 
                  post['supportCount'], 
                  context,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String label, int count, BuildContext context, {bool isActive = false, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final activeBgColor = isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1);
    final activeTextColor = isDark ? Colors.blue[200] : Colors.blue[700];
    final activeBorderColor = isDark ? Colors.blue[700]! : Colors.blue[200]!;

    final inactiveBgColor = isDark ? Colors.grey[800] : Colors.grey[100];
    final inactiveTextColor = isDark ? Colors.grey[300] : Colors.grey[700];
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : inactiveBgColor,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: activeBorderColor, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isActive ? activeTextColor : inactiveTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isActive ? activeTextColor : (isDark ? Colors.grey[400] : Colors.grey[500]),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildWebLayout(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, Color cardColor, Color borderColor, Color accent) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool showSidebar = screenWidth >= 1100;
    final bool isSmallScreen = screenWidth <= 800;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Feed (Center)
        Expanded(
          flex: 7,
          child: Column(
            children: [
               _buildWebCommunityHeader(isDark, textColor, secondaryTextColor, cardColor, borderColor, accent, isSmallScreen),
               Expanded(
                 child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _posts.isEmpty
                    ? Center(child: Text('No posts yet.', style: GoogleFonts.inter(color: secondaryTextColor)))
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 24, vertical: 16),
                        itemCount: _posts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                           return Center(
                             child: ConstrainedBox(
                               constraints: const BoxConstraints(maxWidth: 800),
                               child: _buildPostCard(_posts[index], isDark, cardColor, borderColor, textColor, secondaryTextColor),
                             ),
                           );
                        },
                      ),
               ),
            ],
          ),
        ),

        // Right Sidebar
        if (showSidebar)
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
                  _buildWebRightSidebar(isDark, cardColor, borderColor, textColor, secondaryTextColor, accent),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebCommunityHeader(bool isDark, Color textColor, Color secondaryTextColor, Color cardColor, Color borderColor, Color accent, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: isDark ? AurbitWebTheme.darkTopbar : AurbitWebTheme.lightTopbar,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              if (isMobile) ...[
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: isMobile ? 48 : 80,
                height: isMobile ? 48 : 80,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.8), accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.groups_rounded, color: Colors.white, size: isMobile ? 24 : 40),
              ),
              SizedBox(width: isMobile ? 16 : 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.community['name'] ?? 'Community',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 24 : 32,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.community['username'] != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withOpacity(0.3)),
                        ),
                        child: Text(
                          'c/${widget.community['username']}',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 11 : 13,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMobile ? '${_memberCount} mbrs' : '${_memberCount} members • ${_activeCount} active now',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 12 : 14,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildJoinButton(accent, isDark, borderColor, isMobile),
              if (isMobile) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.info_outline_rounded, color: textColor),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildWebRightSidebar(isDark, cardColor, borderColor, textColor, secondaryTextColor, accent),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinButton(Color accent, bool isDark, Color borderColor, bool isMobile) {
    return ElevatedButton(
      onPressed: _isMember ? _handleLeaveCommunity : _handleJoinCommunity,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isMember ? Colors.transparent : accent,
        foregroundColor: _isMember ? (isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText) : Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: _isMember ? BorderSide(color: borderColor) : BorderSide.none,
      ),
      child: Text(_isMember ? 'Joined' : 'Join Community', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildWebRightSidebar(bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryTextColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sidebarCard(
          'About Community', 
          widget.community['bio'] ?? 'A space for mindful connections and shared orbits.', 
          isDark, cardColor, borderColor, textColor, secondaryTextColor
        ),
        const SizedBox(height: 20),
        _sidebarCard(
          'Community Statistics',
          '• ${_memberCount} Members\n• Created on ${_formatDate(widget.community['created_at'])}\n• Public Community',
          isDark, cardColor, borderColor, textColor, secondaryTextColor
        ),
        const SizedBox(height: 20),
        _sidebarCard(
          'Moderators',
          'Moderation ensures a safe and peaceful environment for everyone.',
          isDark, cardColor, borderColor, textColor, secondaryTextColor,
          buttonLabel: 'View Members',
          onBtnTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityMembersScreen(
                communityId: widget.community['id'],
                communityName: widget.community['name'],
                isAdmin: _isAdmin,
             )));
          }
        ),
        const SizedBox(height: 32),
        if (_isAdmin) ...[
          Text('ADMIN TOOLS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: secondaryTextColor, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _adminActionButton(Icons.settings_outlined, 'Community Settings', isDark, borderColor, textColor, () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => CommunitySettingsScreen(
                communityId: widget.community['id'],
                currentName: widget.community['name'],
                currentBio: widget.community['bio'],
             )));
          }),
        ],
      ],
    );
  }

  Widget _adminActionButton(IconData icon, String label, bool isDark, Color borderColor, Color textColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 12),
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _sidebarCard(String title, String content, bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryTextColor, {String? buttonLabel, VoidCallback? onBtnTap}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          Text(content, style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.5)),
          if (buttonLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBtnTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AurbitWebTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
