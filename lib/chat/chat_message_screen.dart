import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/theme_service.dart';
import '../widgets/verified_badge.dart';
import '../services/mood_service.dart';
import '../services/emoji_analyzer_service.dart';

class ChatMessageScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String moodEmoji;
  final String colorHex;
  final String moodText;
  final bool isVerified;
  final bool isEmbedded;

  const ChatMessageScreen({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.moodEmoji,
    required this.colorHex,
    required this.moodText,
    this.isVerified = false,
    this.isEmbedded = false,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  DateTime _lastTypedTime = DateTime(2000);
  
  List<Message> _messages = [];
  Timer? _pollingTimer;
  bool _isLoadingMessages = true;
  
  Message? _replyMessage; 
  bool _isBlocked = false;
  
  // Dynamic mood tracking
  String _currentMoodText = '';
  String _currentMoodEmoji = '';
  
  // Presence & Typing
  RealtimeChannel? _channel;
  bool _isOtherUserTyping = false;
  Timer? _typingDebounce;
  DateTime? _otherUserLastSeen;
  Timer? _lastSeenTimer; // To refresh "time ago" UI
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
    _markMessagesAsRead();
    // Initial fetch
    _fetchMessages();
    // Start polling
    _startPolling();
    _fetchUserMood();
    _subscribeToMoodChanges(); 
    _setupRealtime();
    _updateLastSeen();
    // Periodically update "time ago" string
    _lastSeenTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    _typingDebounce?.cancel();
    _lastSeenTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _startPolling() {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) _fetchMessages(silent: true);
      });
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final myId = user.id;

    try {
      // Fetch messages between current user and target user
      final response = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$myId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$myId)')
          .order('created_at', ascending: false);
      
      final newMessages = (response as List)
          .map((e) => Message.fromMap(e, myId))
          .toList();

      if (mounted) {
        setState(() {
          _messages = newMessages;
          _isLoadingMessages = false;
        });

        // Mark as read if we have new unread messages
        // Simple check: if last message is from other user and not read
        if (newMessages.isNotEmpty) {
           final lastMsg = newMessages.first; // First item is newest in DESC order
           if (!lastMsg.isMe) {
             _markMessagesAsRead();
           }
        }
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted && !silent) {
         setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final myId = _supabase.auth.currentUser!.id;
    final replyTo = _replyMessage?.id;

    _messageController.clear();
    setState(() {
      _replyMessage = null; // Clear reply state
    });

    try {
      await _supabase.from('messages').insert({
        'content': text,
        'sender_id': myId,
        'receiver_id': widget.userId,
        'reply_to_id': replyTo,
      });
      // Refresh messages immediately
      _fetchMessages(silent: true);
      
      // Auto scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0, // Scroll to bottom (start of reversed list)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Auto-detect mood from message
      _detectAndUpdateMood(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  /// Detect mood from message and update (asynchronously, don't block sending)
  Future<void> _detectAndUpdateMood(String text) async {
    try {
      final analyzer = EmojiAnalyzer();
      
      // Debug: Show what emojis were found
      final details = analyzer.analyzeMoodDetails(text);
      debugPrint('📊 Chat mood analysis: ${details['emojis']} → ${details['dominant_mood']}');
      
      final detectedMood = analyzer.detectMoodFromText(text);
      
      if (detectedMood != null) {
        debugPrint('🎭 Detected mood from chat: $detectedMood');
        final canUpdate = await _canUpdateMood();
        
        if (canUpdate) {
          debugPrint('⏰ Throttle check passed, updating mood...');
          await MoodService().updateMood(
            detectedMood,
            isAutoDetected: true,
            sourceType: 'chat',
          );
        } else {
          debugPrint('⏸️ Throttle active, skipping mood update');
        }
      } else {
        debugPrint('🤷 No clear mood detected from chat message');
      }
    } catch (e) {
      debugPrint('Error detecting mood from chat: $e');
    }
  }

  Future<bool> _canUpdateMood() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('mood_updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['mood_updated_at'] == null) {
        return true;
      }

      final lastUpdate = DateTime.parse(response['mood_updated_at']);
      final difference = DateTime.now().difference(lastUpdate);
      return difference.inSeconds >= 0; 
    } catch (e) {
      return true;
    }
  }

  /// Fetch user's current mood from database
  Future<void> _fetchUserMood() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('current_mood')
          .eq('id', widget.userId)
          .maybeSingle();

      if (response != null && mounted) {
        final mood = (response['current_mood'] as String?) ?? 'Happy';
        setState(() {
          _currentMoodText = 'Feeling ${mood.toLowerCase()}';
          _currentMoodEmoji = _getMoodEmoji(mood);
        });
      }
    } catch (e) {
      debugPrint('Error fetching user mood: $e');
      if (mounted) {
        setState(() {
          _currentMoodText = widget.moodText;
          _currentMoodEmoji = widget.moodEmoji;
        });
      }
    }
  }

  /// Subscribe to real-time mood changes
  void _subscribeToMoodChanges() {
    _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final profile = data.first;
            final mood = (profile['current_mood'] as String?) ?? 'Happy';
            setState(() {
              _currentMoodText = 'Feeling ${mood.toLowerCase()}';
              _currentMoodEmoji = _getMoodEmoji(mood);
            });
          }
        });
  }

  /// Get emoji for a mood
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
      default: return '😊';
    }
  }

  Future<void> _markMessagesAsRead() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      // Use RPC for robust server-side update
      await _supabase.rpc('mark_conversation_read', params: {
        'target_sender_id': widget.userId,
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _checkBlockStatus() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final res = await _supabase
          .from('user_blocks')
          .select()
          .eq('blocker_id', myId)
          .eq('blocked_id', widget.userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isBlocked = res != null;
        });
      }
    } catch (e) {
      // silent error on init
    }
  }

  Future<void> _toggleBlock() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      if (_isBlocked) {
        // Unblock
        await _supabase
            .from('user_blocks')
            .delete()
            .eq('blocker_id', myId)
            .eq('blocked_id', widget.userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
      } else {
        // Block
        await _supabase
            .from('user_blocks')
            .insert({'blocker_id': myId, 'blocked_id': widget.userId});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
      }
      setState(() {
        _isBlocked = !_isBlocked;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showReportDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe why you are reporting this user:'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Reason (e.g. spam, harassment)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                final myId = _supabase.auth.currentUser!.id;
                await _supabase.from('reports').insert({
                  'reporter_id': myId,
                  'reported_id': widget.userId,
                  'reason': controller.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error submitting report: $e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  /// Show clear chat confirmation dialog
  Future<void> _showClearChatDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Are you sure you want to clear all messages in this chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearChat();
    }
  }

  /// Clear all messages in this chat
  Future<void> _clearChat() async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      // Delete all messages between me and this user
      await _supabase.from('messages').delete().or(
        'and(sender_id.eq.$myId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$myId)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared successfully')),
        );
      }
       _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing chat: $e')),
        );
      }
    }
  }

  /// Show delete message options
  Future<void> _showDeleteMessageOptions(Message message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete for me
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: Text(
                'Delete for Me',
                style: GoogleFonts.inter(color: textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(message);
              },
            ),
            // Delete for everyone (only if I'm the sender)
            if (message.isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'Delete for Everyone',
                  style: GoogleFonts.inter(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForEveryone(message);
                },
              ),
            // Cancel
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(
                'Cancel',
                style: GoogleFonts.inter(color: textColor),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Delete message for everyone (hard delete - removes from database)
  Future<void> _deleteMessageForEveryone(Message message) async {
    try {
      await _supabase.from('messages').delete().eq('id', message.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted for everyone')),
        );
      }
       _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
        );
      }
    }
  }

  /// Delete message only for current user
  Future<void> _deleteMessageForMe(Message message) async {
    try {
      await _supabase.from('messages').delete().eq('id', message.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
      _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _setupRealtime() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    // 1. Initial Last Seen Fetch
    try {
       final data = await _supabase.from('profiles').select('last_seen').eq('id', widget.userId).maybeSingle();
       if (data != null && data['last_seen'] != null) {
          setState(() {
            _otherUserLastSeen = DateTime.parse(data['last_seen']);
            _checkOnlineStatus();
          });
       }
    } catch (e) {
      debugPrint('Error fetching last_seen: $e');
    }

    // 2. Setup Channel for Typing & Presence
    final ids = [myId, widget.userId]..sort();
    final roomName = 'chat_${ids.join('_')}';
    
    _channel = _supabase.channel(roomName);
    
    _channel!
      .onBroadcast(event: 'typing', callback: (payload) {
        if (payload['user_id'] == widget.userId) {
          setState(() => _isOtherUserTyping = true);
          
          // Auto-clear typing status after 3 seconds of no events
          _typingDebounce?.cancel();
          _typingDebounce = Timer(const Duration(seconds: 3), () {
             if (mounted) setState(() => _isOtherUserTyping = false);
          });
        }
      })
      .subscribe();

    // 3. Listen for profile changes (Last Seen)
    _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .listen((data) {
           if (data.isNotEmpty && mounted) {
              final lastSeenStr = data.first['last_seen'] as String?;
              if (lastSeenStr != null) {
                setState(() {
                  _otherUserLastSeen = DateTime.parse(lastSeenStr);
                  _checkOnlineStatus();
                });
              }
           }
        });
        
    // 4. Typing Listener on Controller
    _messageController.addListener(() {
      final text = _messageController.text;
      if (text.isNotEmpty) {
        final now = DateTime.now();
        if (now.difference(_lastTypedTime).inSeconds > 2) {
           _lastTypedTime = now;
           _sendTypingEvent();
        }
      }
    });
  }

  void _checkOnlineStatus() {
    if (_otherUserLastSeen == null) {
      _isOnline = false;
      return;
    }
    final diff = DateTime.now().difference(_otherUserLastSeen!);
    _isOnline = diff.inMinutes < 2; // Online if active in last 2 mins
  }

  Future<void> _sendTypingEvent() async {
     try {
       await _channel?.sendBroadcastMessage(
         event: 'typing',
         payload: {'user_id': _supabase.auth.currentUser!.id},
       );
     } catch (e) {
       // Debug print
     }
  }

  Future<void> _updateLastSeen() async {
    try {
      // Create migration if not exists for 'last_seen' column
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;
      
      await _supabase.from('profiles').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', myId);
    } catch (_) {}
  }
  
  String _buildStatusText() {
    if (_isOtherUserTyping) {
      return 'Typing...';
    }
    
    // If we have mood from previous logic, append/mix?
    // User requested "typing indicator and last seen". 
    // Let's prioritize presence, then fall back to mood.
    
    if (_isOnline) {
      return 'Online';
    }
    
    if (_otherUserLastSeen != null) {
      final diff = DateTime.now().difference(_otherUserLastSeen!);
      if (diff.inMinutes < 60) {
        return 'Last seen ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return 'Last seen ${diff.inHours}h ago';
      } else {
        return 'Last seen ${diff.inDays}d ago';
      }
    }
    
    // Fallback to Mood if offline/unknown
    return _currentMoodText.isNotEmpty ? _currentMoodText : widget.moodText;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? Colors.grey[400] : Colors.grey[600];
    final inputBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    final body = Column(
      children: [
        if (widget.isEmbedded) _buildHeader(context, bgColor, textColor, secondaryText, borderColor),
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet.\nSay hello!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: secondaryText),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        Message? repliedMsg;
                        if (msg.replyToId != null) {
                          try {
                            repliedMsg = _messages.firstWhere((m) => m.id == msg.replyToId);
                          } catch (_) {}
                        }
                        return _buildMessageBubble(msg, isDark, repliedMsg);
                      },
                    ),
        ),
        _buildInputArea(isDark, inputBg, borderColor, textColor),
      ],
    );

    if (widget.isEmbedded) {
      return Container(
        color: bgColor,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildHeader(context, bgColor, textColor, secondaryText, borderColor) as PreferredSizeWidget,
      body: body,
    );
  }

  Widget _buildHeader(BuildContext context, Color bgColor, Color textColor, Color? secondaryText, Color borderColor) {
    final headerContent = Row(
      children: [
        if (!widget.isEmbedded) IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context, true),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(int.parse('0xFF${widget.colorHex}')),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                    ? (widget.avatarUrl!.contains('.svg') || widget.avatarUrl!.contains('dicebear'))
                        ? SvgPicture.network(
                            widget.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            placeholderBuilder: (c) => Text(widget.name[0], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        : Image.network(
                            widget.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                          )
                    : Text(widget.name.isNotEmpty ? widget.name[0] : '?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: bgColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  _currentMoodEmoji.isNotEmpty ? _currentMoodEmoji : widget.moodEmoji, 
                  style: const TextStyle(fontSize: 10)
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UsernameWithBadge(
              username: widget.name,
              isVerified: widget.isVerified,
              textStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              badgeSize: 16,
              badgeColor: const Color(0xFF1DA1F2),
            ),
            Text(
              _buildStatusText(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _isOtherUserTyping ? Colors.green : secondaryText,
                fontWeight: _isOtherUserTyping ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: headerContent,
      );
    }

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: headerContent,
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: textColor),
          onSelected: (value) {
            if (value == 'block') {
              _toggleBlock();
            } else if (value == 'report') {
              _showReportDialog();
            } else if (value == 'clear_chat') {
              _showClearChatDialog();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'clear_chat',
              child: Row(
                children: [
                  const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text('Clear Chat', style: GoogleFonts.inter()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  const Icon(Icons.flag, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text('Report User', style: GoogleFonts.inter()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(
                    _isBlocked ? Icons.lock_open : Icons.block, 
                    color: _isBlocked ? Colors.green : Colors.red, 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBlocked ? 'Unblock User' : 'Block User', 
                    style: GoogleFonts.inter()
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message msg, bool isDark, Message? repliedMsg) {
    // Swipe to reply - right for received messages, left for sent messages
    return Dismissible(
      key: Key('msg_${msg.id}'),
      dismissThresholds: {
        DismissDirection.endToStart: 0.2,
        DismissDirection.startToEnd: 0.2, // Requiring 20% swipe to trigger, reduced from default to be smoother but not too annoying
      },
      direction: msg.isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        setState(() {
          _replyMessage = msg;
        });
        return false; // Don't actually dismiss
      },
      background: Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: msg.isMe ? 0 : 20,
            right: msg.isMe ? 20 : 0,
          ),
          child: Icon(Icons.reply_rounded, color: isDark ? Colors.white70 : Colors.black54),
        ),
      ),
      child: Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => _showDeleteMessageOptions(msg),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: msg.isMe 
                        ? (isDark ? Colors.grey[300] : Colors.grey[200]) 
                        : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: msg.isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: msg.isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    border: msg.isMe ? null : Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nested Reply Display
                    if (repliedMsg != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: Colors.black45, width: 4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repliedMsg.isMe ? 'You' : widget.name,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repliedMsg.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Message Content
                    Text(
                      msg.text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: msg.isMe ? Colors.black : (isDark ? Colors.white : Colors.black),
                        height: 1.4,
                      ).copyWith(
                        fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                      ),
                    ),
                  ],
                ),
              ), // Container
              ), // GestureDetector
              const SizedBox(height: 2),
              Text(
                _formatTime(msg.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    // Simple time formatting HH:MM AM/PM
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  Widget _buildInputArea(bool isDark, Color bgColor, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Reply Preview Indicator
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyMessage!.isMe ? 'yourself' : widget.name}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                        Text(
                          _replyMessage!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyMessage = null),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 50,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // TODO: Implement emoji picker
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: GoogleFonts.inter(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                            isDense: true, 
                          ),
                          textAlignVertical: TextAlignVertical.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF757575),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Message {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool isMe;
  final String senderId;
  final String receiverId;
  final String? replyToId;

  Message({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.isMe,
    required this.senderId,
    required this.receiverId,
    this.replyToId,
  });

  factory Message.fromMap(Map<String, dynamic> map, String myUserId) {
    return Message(
      id: map['id'],
      text: map['content'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      isMe: map['sender_id'] == myUserId,
      senderId: map['sender_id'],
      receiverId: map['receiver_id'],
      replyToId: map['reply_to_id'],
    );
  }
}
