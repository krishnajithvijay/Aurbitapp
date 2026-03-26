import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/theme_service.dart';
import 'chat_message_screen.dart';
import '../profile/profile_screen.dart';
import '../widgets/verified_badge.dart';
import '../services/notification_service.dart';
import '../services/user_activity_service.dart';
import 'package:flutter/foundation.dart';
import '../mobile/chat_mobile.dart';
import '../web/chat_web.dart';
import '../web/aurbit_web_theme.dart';
import '../notifications/notification_screen.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onMessagesRead;
  final int notificationCount;
  
  const ChatScreen({super.key, this.onMessagesRead, this.notificationCount = 0});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class ChatUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String moodEmoji;
  final String colorHex;
  final bool isVerified;
  final bool isActive; // NEW: Track if user is currently active
  final bool isMuted; // NEW: Track if user is muted
  
  // Mock chat data
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String moodText;

  ChatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.moodEmoji,
    required this.colorHex,
    this.isVerified = false,
    this.isActive = false, // NEW: Default to inactive
    this.isMuted = false, // NEW: Default to unmuted
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.moodText,
  });
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Lists for the two tabs
  List<ChatUser> _innerOrbitUsers = [];
  List<ChatUser> _outerOrbitUsers = [];
  bool _isLoading = true;
  String? _userAvatarUrl;
  String? _userMoodEmoji;

  RealtimeChannel? _messageSubscription;
  Timer? _pollingTimer;
  ChatUser? _selectedUser; // Currently selected user for web layout

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserAvatar();
    _fetchCurrentUserMood();
    _fetchChatUsers();

    // Start polling every 5 seconds
    _startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Poll for new message updates every 5 seconds
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      // Refresh list to show new message snippets and unread counts
      if (mounted) {
         // We do a silent fetch if possible or just normal fetch
         // Since _fetchChatUsers calls setState, it might cause re-renders which is acceptable for updates
         // Ideally we check if tab is visible, but this is simple enough
         _fetchChatUsers();

      }
    });
  }



  Future<void> _fetchCurrentUserMood() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('current_mood')
          .eq('id', userId)
          .maybeSingle();

      if (mounted && data != null) {
        final mood = data['current_mood']?.toString();
        if (mood != null) {
          String emoji = '😊';
          switch (mood) {
            case 'Happy': emoji = '😊'; break;
            case 'Sad': emoji = '😢'; break;
            case 'Tired': emoji = '😴'; break;
            case 'Irritated': emoji = '😤'; break;
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
            _userAvatarUrl = data['avatar_url'].toString();
          });
        }
      } catch (e) { /* ignore */ }
    }
  }



  Future<void> _fetchChatUsers() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch orbit status
      final List<dynamic> savedOrbitData = await Supabase.instance.client
          .from('user_orbits')
          .select('friend_id, orbit_type') // Correct table and columns
          .eq('user_id', userId);

      final Map<String, String> orbitLayerMap = {};
      final List<String> friendIds = [];

      for (var item in savedOrbitData) {
        final fId = item['friend_id']?.toString() ?? '';
        final layer = item['orbit_type']?.toString();
        if (fId.isNotEmpty) {
           orbitLayerMap[fId] = layer ?? 'outer';
           friendIds.add(fId);
        }
      }

      if (friendIds.isEmpty) {
        if (mounted) {
          setState(() {
            _innerOrbitUsers = [];
            _outerOrbitUsers = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch profiles for friends
      final List<dynamic> profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, is_verified, current_mood') // Added current_mood
          .filter('id', 'in', friendIds); // Only fetch friends

      final List<String> profileIds = profiles.map((p) => p['id'] as String).toList();

      // (Step 3 removed)

      // 4. Fetch ALL messages involving current user to determine last message & unread count
      final List<dynamic> allMessages = await Supabase.instance.client
          .from('messages')
          .select('*')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      // Process messages: Map<OtherUserId, LatestMessageData>
      final Map<String, dynamic> lastMessagesMap = {};
      final Map<String, int> unreadCountsMap = {};

      for (var msg in allMessages) {
        final senderId = msg['sender_id'] as String;
        final receiverId = msg['receiver_id'] as String;
        final isMe = senderId == userId;
        final otherId = isMe ? receiverId : senderId;

        // Init unread count
        if (!unreadCountsMap.containsKey(otherId)) {
          unreadCountsMap[otherId] = 0;
        }

        // Count unread: If I am the receiver AND it's not read
        if (!isMe && (msg['is_read'] == null || msg['is_read'] == false)) {
          unreadCountsMap[otherId] = unreadCountsMap[otherId]! + 1;
        }

        // Capture latest message (since list is ordered desc, first encounter is latest)
        if (!lastMessagesMap.containsKey(otherId)) {
          lastMessagesMap[otherId] = {
            'content': msg['content'],
            'created_at': msg['created_at'],
          };
        }
      }

      // 5. Fetch activity status for all users
      Map<String, bool> activityStatusMap = {};
      try {
        final activityService = UserActivityService();
        activityStatusMap = await activityService.getUsersActivityStatus(profileIds);
      } catch (e) {
        debugPrint('Error fetching activity status: $e');
        // Continue with empty map - all users will show as inactive
      }
      
      // 5b. Fetch Muted Users
      Set<String> mutedUserIds = {};
      try {
        final mutedData = await Supabase.instance.client
            .from('muted_users')
            .select('muted_user_id')
            .eq('user_id', userId);
        
        for (var m in mutedData) {
          if (m['muted_user_id'] != null) {
            mutedUserIds.add(m['muted_user_id'] as String);
          }
        }
      } catch (e) {
          debugPrint('Error fetching muted users: $e');
      }

      // 6. Build ChatUser objects & Categorize
      final random = Random();
      final List<ChatUser> inner = [];
      final List<ChatUser> outer = [];

      for (var p in profiles) {
        final pid = p['id'] as String;
        final username = p['username'] ?? 'User';
        final avatarUrl = p['avatar_url'] as String?;
        final mood = (p['current_mood'] as String?) ?? 'Happy';
        final isActive = activityStatusMap[pid] ?? false; // Get real activity status
        final isMuted = mutedUserIds.contains(pid);
        
        String emoji = '😊';
        switch (mood) {
          case 'Happy': emoji = '😊'; break;
          case 'Sad': emoji = '😢'; break;
          case 'Tired': emoji = '😴'; break;
          case 'Irritated': emoji = '😤'; break;
          case 'Lonely': emoji = '☁️'; break;
          case 'Bored': emoji = '😐'; break;
          case 'Peaceful': emoji = '😌'; break;
          case 'Grateful': emoji = '🙏'; break;
          default: emoji = '😊'; // Default happy
        }

        // Use deterministic color based on user ID to prevent flickering
        final colors = ['FF7043', '7E57C2', 'FFA726', 'EF5350', 'EC407A', '5C6BC0', '26C6DA', '43A047'];
        // Use hash of ID to pick color consistently
        final colorIndex = pid.codeUnits.fold(0, (a, b) => a + b) % colors.length;
        final color = colors[colorIndex];

        // Get Real Message Data
        String lastMsg = "Start a conversation";
        String timeAgo = "";
        int unread = 0;

        if (lastMessagesMap.containsKey(pid)) {
          final data = lastMessagesMap[pid];
          lastMsg = data['content'] ?? "";
          if (data['created_at'] != null) {
            final date = DateTime.parse(data['created_at']).toLocal();
            final now = DateTime.now();
            final diff = now.difference(date);
            if (diff.inMinutes < 60) {
              timeAgo = '${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              timeAgo = '${diff.inHours}h ago';
            } else {
              timeAgo = '${diff.inDays}d ago';
            }
          }
          unread = unreadCountsMap[pid] ?? 0;
        }

        final chatUser = ChatUser(
          id: pid, 
          name: username, 
          avatarUrl: avatarUrl, 
          moodEmoji: emoji, 
          colorHex: color,
          isVerified: (p['is_verified'] as bool?) ?? false,
          isActive: isActive, // NEW: Set real activity status
          isMuted: isMuted,
          lastMessage: lastMsg,
          time: timeAgo,
          unreadCount: unread, 
          moodText: 'Feeling ${mood.toLowerCase()}',
        );

        // Sort into Inner or Outer
        final layer = orbitLayerMap[pid];
        if (layer == 'inner') {
          inner.add(chatUser);
        } else {
          outer.add(chatUser);
        }
      }

      if (mounted) {
        setState(() {
          _innerOrbitUsers = inner;
          _outerOrbitUsers = outer;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching chat users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb  = kIsWeb;
    final textColor   = isWeb ? (isDark ? AurbitWebTheme.darkText   : AurbitWebTheme.lightText)   : (isDark ? Colors.white : Colors.black);
    final borderColor = isWeb ? (isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder) : (isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE));
    final accent      = AurbitWebTheme.accentPrimary;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb || screenWidth >= 650;

    final headerWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) _buildHeader(context),
        if (isDesktop) _buildWebChatHeader(context, isDark, textColor),
        if (!isDesktop) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8.0, 24, 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Messages',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );

    final tabsWidget = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: isDesktop ? accent : (isDark ? Colors.white : Colors.black),
        labelColor: isDesktop ? accent : (isDark ? Colors.white : Colors.black),
        unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey[400],
        indicatorWeight: 2,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Text('Inner Orbit'),
                 const SizedBox(width: 8),
                 if (_innerOrbitUsers.isNotEmpty) _buildCountBadge(_innerOrbitUsers.length, context),
              ],
            ),
          ),
          Tab(
             child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Text('Outer Orbit'),
                 const SizedBox(width: 8),
                 if (_outerOrbitUsers.isNotEmpty) _buildCountBadge(_outerOrbitUsers.length, context),
              ],
            ),
          ),
        ],
      ),
    );

    final contentWidget = _isLoading
      ? Center(child: CircularProgressIndicator(color: isDesktop ? accent : (isDark ? Colors.white : Colors.black))) 
      : TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(_innerOrbitUsers),
          _buildChatList(_outerOrbitUsers),
        ],
      );

    final isNarrow = screenWidth <= 800;

    return Scaffold(
      backgroundColor: isDesktop 
          ? (isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg)
          : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isDesktop 
          ? ChatWeb(
              header: headerWidget,
              tabs: tabsWidget,
              sideListContent: contentWidget,
              onBack: isNarrow ? () => setState(() => _selectedUser = null) : null,
              conversationContent: _selectedUser == null ? null : ChatMessageScreen(
                userId: _selectedUser!.id,
                name: _selectedUser!.name,
                avatarUrl: _selectedUser!.avatarUrl,
                moodEmoji: _selectedUser!.moodEmoji,
                colorHex: _selectedUser!.colorHex,
                moodText: _selectedUser!.moodText,
                isEmbedded: true, // Always embedded on web to use ChatWeb's header/back button
              ),
            )
          : ChatMobile(
              header: headerWidget,
              tabs: tabsWidget,
              content: contentWidget,
            ),
      ),
    );
  }

  Widget _buildWebChatHeader(BuildContext context, bool isDark, Color textColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth <= 800;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          if (isNarrow) ...[
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          Text('Chats', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.inter(
          fontSize: 12, 
          color: isDark ? Colors.white : Colors.black, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildChatList(List<ChatUser> users) {
    if (users.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchChatUsers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
             SizedBox(
               height: MediaQuery.of(context).size.height * 0.5,
               child: Center(
                 child: Text('No one in this orbit yet.', style: GoogleFonts.inter(color: Colors.grey)),
               ),
             ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchChatUsers,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildChatCard(users[index], context);
        },
      ),
    );
  }

  Widget _buildChatCard(ChatUser user, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    user.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    color: user.isMuted ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    user.isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                    style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    user.isMuted
                        ? 'Resume receiving notifications from ${user.name}'
                        : 'Stop receiving notifications from ${user.name}',
                    style: GoogleFonts.inter(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final currentUser = Supabase.instance.client.auth.currentUser;
                    if (currentUser == null) return;

                    try {
                      if (user.isMuted) {
                        // Unmute logic
                        await Supabase.instance.client
                            .from('muted_users')
                            .delete()
                            .eq('user_id', currentUser.id)
                            .eq('muted_user_id', user.id);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notifications unmuted for ${user.name}')),
                          );
                        }
                      } else {
                        // Mute logic
                        await Supabase.instance.client.from('muted_users').insert({
                          'user_id': currentUser.id,
                          'muted_user_id': user.id,
                        });
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notifications muted for ${user.name}')),
                          );
                        }
                      }
                      // Refresh the list to update UI state
                      _fetchChatUsers();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
      onTap: () async {
        // Optimistically clear unread count for instant feedback
        setState(() {
          // Check inner list
          final innerIndex = _innerOrbitUsers.indexWhere((u) => u.id == user.id);
          if (innerIndex != -1) {
            final old = _innerOrbitUsers[innerIndex];
            _innerOrbitUsers[innerIndex] = ChatUser(
              id: old.id,
              name: old.name,
              avatarUrl: old.avatarUrl,
              moodEmoji: old.moodEmoji,
              colorHex: old.colorHex,
              moodText: old.moodText,
              lastMessage: old.lastMessage,
              time: old.time,
              unreadCount: 0, // Clear count
              isVerified: old.isVerified,
              isActive: old.isActive, // Preserve activity status
            );
          } else {
             // Check outer list
            final outerIndex = _outerOrbitUsers.indexWhere((u) => u.id == user.id);
            if (outerIndex != -1) {
              final old = _outerOrbitUsers[outerIndex];
              _outerOrbitUsers[outerIndex] = ChatUser(
                id: old.id,
                name: old.name,
                avatarUrl: old.avatarUrl,
                moodEmoji: old.moodEmoji,
                colorHex: old.colorHex,
                moodText: old.moodText,
                lastMessage: old.lastMessage,
                time: old.time,
                unreadCount: 0, // Clear count
                isVerified: old.isVerified,
                isActive: old.isActive, // Preserve activity status
              );
            }
          }
        });

        if (kIsWeb) {
          setState(() {
            _selectedUser = user;
          });
          widget.onMessagesRead?.call();
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatMessageScreen(
              userId: user.id,
              name: user.name,
              avatarUrl: user.avatarUrl,
              moodEmoji: user.moodEmoji,
              colorHex: user.colorHex,
              moodText: user.moodText,
              isVerified: user.isVerified, 
            ),
          ),
        );
        
        widget.onMessagesRead?.call();
        _fetchChatUsers();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${user.colorHex}')),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: ClipOval(
                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? (user.avatarUrl!.toString().contains('.svg') || user.avatarUrl!.toString().contains('dicebear'))
                          ? SvgPicture.network(
                              user.avatarUrl!,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                              placeholderBuilder: (c) => Text(user.name[0], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            )
                          : Image.network(
                              user.avatarUrl!,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                            )
                      : Text(user.name.isNotEmpty ? user.name[0] : '?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                ),
                // Mood
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(user.moodEmoji, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                // Online/Active indicator - only show if user is actually active
                if (user.isActive)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853), // Green
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       UsernameWithBadge(
                         username: user.name,
                         isVerified: user.isVerified,
                         textStyle: GoogleFonts.inter(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: textColor,
                         ),
                         badgeSize: 16,
                         badgeColor: const Color(0xFF1DA1F2),
                       ),
Row(
                          children: [
                            Icon(
                              user.isMuted 
                                  ? Icons.notifications_off_outlined 
                                  : Icons.notifications_active_outlined,
                              size: 14,
                              color: user.isMuted 
                                  ? Colors.red 
                                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.time,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Text(
                           user.lastMessage,
                           style: GoogleFonts.inter(
                             fontSize: 14,
                             color: isDark ? Colors.grey[400] : Colors.grey[600],
                             height: 1.4,
                           ),
                           maxLines: 2,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       if (user.unreadCount > 0)
                         Container(
                           margin: const EdgeInsets.only(left: 8),
                           width: 20,
                           height: 20,
                           decoration: BoxDecoration(
                             color: isDark ? Colors.white : Colors.black,
                             shape: BoxShape.circle,
                           ),
                           alignment: Alignment.center,
                           child: Text(
                             '${user.unreadCount}',
                             style: GoogleFonts.inter(
                               color: isDark ? Colors.black : Colors.white,
                               fontSize: 10,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                     ],
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Reused generic header from other screens to maintain consistency
  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Aurbit',
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          Row(
            children: [
               _buildHeaderButton(
                 icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                 onTap: () {
                   ThemeService().toggleTheme();
                 },
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: _userAvatarUrl != null 
                              ? (_userAvatarUrl!.contains('.svg') || _userAvatarUrl!.contains('dicebear'))
                                  ? SvgPicture.network(_userAvatarUrl!, fit: BoxFit.cover, width: 40, height: 40)
                                  : Image.network(_userAvatarUrl!, fit: BoxFit.cover, width: 40, height: 40)
                              : Icon(Icons.person_outline, size: 20, color: isDark ? Colors.black : Colors.white),
                        ),
                        if (_userMoodEmoji != null)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)]
                              ),
                              alignment: Alignment.center,
                              child: Text(_userMoodEmoji!, style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                      ],
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
}
