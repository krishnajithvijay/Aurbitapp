import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/notification_service.dart';
import '../services/orbit_service.dart';
import '../space/post_detail_screen.dart';
import '../community/community_post_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final OrbitService _orbitService = OrbitService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchNotifications(silent: true);
    });
  }

  Future<void> _fetchNotifications({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    setState(() {
      for (var notification in _notifications) {
        notification['is_read'] = true;
      }
    });
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    if (!notification['is_read']) {
      await _notificationService.markAsRead(notification['id']);
      setState(() => notification['is_read'] = true);
    }

    // Navigate based on type
    if (notification['type'] == 'reaction' || 
        notification['type'] == 'comment' || 
        notification['type'] == 'reply' ||
        notification['type'] == 'trending_post') {
      if (notification['post'] != null) {
        // Navigate to post detail
        final postData = notification['post'];
        final author = postData['profiles'];
        
        final post = {
          'id': postData['id'],
          'content': postData['content'],
          'user_id': postData['user_id'], // Important for deletion/ownership checks
          'username': author != null ? author['username'] : (notification['sender']?['username'] ?? 'System'),
          'avatar_url': author != null ? author['avatar_url'] : notification['sender']?['avatar_url'],
          'isVerified': author != null ? (author['is_verified'] ?? false) : false,
          'timeAgo': postData['created_at'] != null ? _timeAgo(postData['created_at']) : _timeAgo(notification['created_at']),
          'mood': postData['mood'] ?? 'Neutral',
          'moodEmoji': '😐', 
        };
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: post),
          ),
        );
      }
    } else if (notification['type'] == 'community_new_post') {
       if (notification['community_post_id'] != null) {
          // Manual fetch might be needed if not joined by query, but let's try assuming minimal info
          // We need to fetch the post content really
          try {
             final supabase = Supabase.instance.client;
             final postRes = await supabase.from('community_posts').select().eq('id', notification['community_post_id']).single();
             final userRes = await supabase.from('profiles').select().eq('id', postRes['user_id']).single();
             
             final postMap = {
               ...postRes,
               'username': userRes['username'],
               'avatar_url': userRes['avatar_url'],
             };
             
             if (mounted) {
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommunityPostDetailScreen(post: postMap),
                ),
              );
             }
          } catch(e) {
             debugPrint('Error navigating to community post: $e');
          }
       }
    }
  }

  Future<void> _handleOrbitRequest(
    Map<String, dynamic> notification,
    String action, // 'accept_inner', 'accept_outer', or 'ignore'
  ) async {
    try {
      if (action == 'ignore') {
        // Just delete the notification
        await _notificationService.deleteNotification(notification['id']);
        setState(() {
          _notifications.removeWhere((n) => n['id'] == notification['id']);
        });
      } else {
        // Handle accept (you'll need to implement orbit/friend system)
        final orbitType = action == 'accept_inner' ? 'inner' : 'outer';
        
        // Accept Orbit Request
        await _orbitService.acceptOrbitRequest(
          senderId: notification['sender_id'],
          myOrbitForSender: orbitType,
          senderOrbitForMe: notification['orbit_type'] ?? 'outer',
        );

        // Delete notification
        await _notificationService.deleteNotification(notification['id']);
        
        // Send acceptance notification back to sender
        await _notificationService.createOrbitAcceptNotification(
          recipientId: notification['sender_id'],
          orbitType: orbitType,
        );
        
        setState(() {
          _notifications.removeWhere((n) => n['id'] == notification['id']);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${notification['sender']['username']} to your ${orbitType == 'inner' ? 'Inner' : 'Outer'} Orbit'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling orbit request: $e');
    }
  }

  String _timeAgo(String dateString) {
    final created = DateTime.parse(dateString).toLocal();
    final diff = DateTime.now().difference(created);
    
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'reaction':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'reply':
        return Icons.reply_rounded;
      case 'orbit_request':
        return Icons.person_add_rounded;
      case 'orbit_accept':
        return Icons.group_add_rounded;
      case 'message':
        return Icons.message_rounded;
      case 'trending_post':
        return Icons.whatshot_rounded;
      case 'community_new_post':
        return Icons.groups_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                color: isDark ? Colors.blue[300] : Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _buildNotificationCard(
                        notification,
                        isDark,
                        cardColor,
                        borderColor,
                        textColor,
                        secondaryTextColor ?? Colors.grey,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] as String;
    final sender = notification['sender'] as Map<String, dynamic>?;
    final timeAgo = _timeAgo(notification['created_at']);

    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? borderColor : (isDark ? Colors.blue[700]! : Colors.blue[200]!),
            width: isRead ? 1 : 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with icon badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAvatar(sender?['avatar_url'], 48, isDark),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getIconColor(type, isDark),
                      shape: BoxShape.circle,
                      border: Border.all(color: cardColor, width: 2),
                    ),
                    child: Icon(
                      _getNotificationIcon(type),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  
                  if (notification['body'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification['body'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryTextColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // Action buttons for orbit requests
                  if (type == 'orbit_request') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Accept',
                            isDark ? Colors.grey[900]! : Colors.black,
                            Colors.white,
                            () => _showOrbitOptions(notification),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            'Decline',
                            Colors.transparent,
                            textColor,
                            () => _handleOrbitRequest(notification, 'ignore'),
                            borderColor: borderColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Unread indicator
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[400] : Colors.blue[600],
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOrbitOptions(Map<String, dynamic> notification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to Orbit',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildOrbitOptionButton(
              'Add to Inner Orbit',
              'Close friends and family',
              Icons.favorite_rounded,
              () {
                Navigator.pop(context);
                _handleOrbitRequest(notification, 'accept_inner');
              },
              isDark,
            ),
            const SizedBox(height: 12),
            _buildOrbitOptionButton(
              'Add to Outer Orbit',
              'Friends and acquaintances',
              Icons.group_rounded,
              () {
                Navigator.pop(context);
                _handleOrbitRequest(notification, 'accept_outer');
              },
              isDark,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitOptionButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color bgColor,
    Color textColor,
    VoidCallback onTap, {
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, double size, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url != null
            ? (url.contains('.svg') || url.contains('dicebear'))
                ? SvgPicture.network(url, fit: BoxFit.cover)
                : Image.network(url, fit: BoxFit.cover)
            : Icon(
                Icons.person_outline,
                color: isDark ? Colors.white : Colors.grey[800],
                size: size * 0.6,
              ),
      ),
    );
  }

  Color _getIconColor(String type, bool isDark) {
    switch (type) {
      case 'reaction':
        return Colors.red;
      case 'comment':
      case 'reply':
        return Colors.blue;
      case 'orbit_request':
      case 'orbit_accept':
        return Colors.purple;
      case 'message':
        return Colors.green;
      case 'trending_post':
        return Colors.orange;
      case 'community_new_post':
        return Colors.teal;
      default:
        return isDark ? Colors.grey[700]! : Colors.grey[400]!;
    }
  }
}
