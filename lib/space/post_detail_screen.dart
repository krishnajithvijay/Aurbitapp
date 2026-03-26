import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/verified_badge.dart';
import '../screens/user_profile_screen.dart';
import 'package:flutter/foundation.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _rootComments = [];
  Map<String, List<Map<String, dynamic>>> _repliesMap = {};
  Map<String, dynamic>? _replyingTo;
  bool _isLoadingComments = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _fetchComments();
    _fetchReactions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Reaction State
  int _relateCount = 0;
  int _notAloneCount = 0;
  bool _isRelateActive = false;
  bool _isNotAloneActive = false;

  Future<void> _fetchReactions() async {
    try {
      final postId = widget.post['id'];
      if (postId == null) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // 1. Get Counts from posts table (assuming backend trigger updates them, or we count manually)
      // For now, let's fetch the post again to get fresh counts if they exist on the record
      // OR count from the reactions table directly. Counting directly is safer for now.
      
      final relateCountRes = await Supabase.instance.client
          .from('post_reactions')
          .count()
          .eq('post_id', postId)
          .eq('reaction_type', 'i_relate');

       final notAloneCountRes = await Supabase.instance.client
          .from('post_reactions')
          .count()
          .eq('post_id', postId)
          .eq('reaction_type', 'youre_not_alone');

      // 2. Check if current user has reacted
      bool relateActive = false;
      bool notAloneActive = false;

      if (userId != null) {
        final myReactions = await Supabase.instance.client
            .from('post_reactions')
            .select('reaction_type')
            .eq('post_id', postId)
            .eq('user_id', userId);
        
        final types = (myReactions as List).map((e) => e['reaction_type']).toSet();
        relateActive = types.contains('i_relate');
        notAloneActive = types.contains('youre_not_alone');
      }

      if (mounted) {
        setState(() {
          _relateCount = relateCountRes;
          _notAloneCount = notAloneCountRes;
          _isRelateActive = relateActive;
          _isNotAloneActive = notAloneActive;
        });
      }

    } catch (e) {
      debugPrint('Error fetching reactions: $e');
    }
  }

  Future<void> _toggleReaction(String type) async {
    final postId = widget.post['id'];
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null) return;

    final isRelate = type == 'i_relate';
    final wasActive = isRelate ? _isRelateActive : _isNotAloneActive;
    final otherWasActive = isRelate ? _isNotAloneActive : _isRelateActive;
    
    // Optimistic Update
    setState(() {
      if (isRelate) {
        if (_isRelateActive) {
          // Toggle Off
          _relateCount--;
          _isRelateActive = false;
        } else {
          // Toggle On
          _relateCount++;
          _isRelateActive = true;
          // Deactivate other if active
          if (_isNotAloneActive) {
            _notAloneCount--;
            _isNotAloneActive = false;
          }
        }
      } else {
        // Not Alone
        if (_isNotAloneActive) {
          // Toggle Off
          _notAloneCount--;
          _isNotAloneActive = false;
        } else {
          // Toggle On
          _notAloneCount++;
          _isNotAloneActive = true;
          // Deactivate other if active
          if (_isRelateActive) {
            _relateCount--;
            _isRelateActive = false;
          }
        }
      }
    });

    try {
      if (wasActive) {
        // If it was active, we are turning it OFF. Just delete.
        await Supabase.instance.client.from('post_reactions').delete().match({
          'user_id': user.id,
          'post_id': postId,
          'reaction_type': type,
        });
      } else {
        // If it was inactive, we are turning it ON.
        
        // 1. Delete the other reaction if it existed
        if (otherWasActive) {
          await Supabase.instance.client.from('post_reactions').delete().match({
            'user_id': user.id,
            'post_id': postId,
            'reaction_type': isRelate ? 'youre_not_alone' : 'i_relate',
          });
        }
        
        // 2. Insert new reaction
        await Supabase.instance.client.from('post_reactions').insert({
          'user_id': user.id,
          'post_id': postId,
          'reaction_type': type,
        });
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      if (mounted) {
        // Revert optimistic update (simplest is just re-fetch)
        _fetchReactions(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update reaction')));
      }
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await Supabase.instance.client
          .from('comments')
          .select()
          .eq('post_id', widget.post['id'])
          .order('created_at', ascending: true);
      
      var data = response as List<dynamic>;

      // Get profiles
      final userIds = data.map((e) => e['user_id'] as String).toSet().toList();
      Map<String, dynamic> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, is_verified')
          .filter('id', 'in', userIds);
        profilesMap = { for (var p in profilesResponse) p['id'] as String: p };
      }

      // Process comments with metadata
      List<Map<String, dynamic>> allComments = data.map<Map<String, dynamic>>((c) {
         final profile = profilesMap[c['user_id']] ?? {};
         return {
           ...c as Map<String, dynamic>,
           'username': profile['username'] ?? 'User',
           'avatar_url': profile['avatar_url'],
           'isVerified': (profile['is_verified'] as bool?) ?? false,
         };
      }).toList();

      // Build Conversation Trees
      List<Map<String, dynamic>> roots = [];
      Map<String, List<Map<String, dynamic>>> replies = {};

      // 1. Get roots
      roots = allComments.where((c) => c['parent_id'] == null).toList();

      // Helper to recursively get children
      List<Map<String, dynamic>> getDescendants(String parentId, int depth) {
        List<Map<String, dynamic>> descendants = [];
        var children = allComments.where((c) => c['parent_id'] == parentId).toList();
        
        // Sort children by created_at (oldest first usually for comments)
        children.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));

        for (var child in children) {
          // Add child with depth info
          Map<String, dynamic> childWithDepth = Map.from(child);
          childWithDepth['depth'] = depth;
          descendants.add(childWithDepth);
          
          // Recursively add grandchildren
          descendants.addAll(getDescendants(child['id'], depth + 1));
        }
        return descendants;
      }

      // 2. For each root, build its flattened tree
      for (var root in roots) {
         var rootId = root['id'] as String;
         replies[rootId] = getDescendants(rootId, 1);
      }

      if (mounted) {
        setState(() {
          _rootComments = roots;
          _repliesMap = replies;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _deletePost() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || widget.post['user_id'] != user.id) {
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
      await Supabase.instance.client
          .from('posts')
          .delete()
          .eq('id', widget.post['id']);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
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

  Future<void> _deleteComment(String commentId, String userId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || userId != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own comments')),
      );
      return;
    }

    final shouldDelete = await _showDeleteDialog(
      context,
      'Delete Comment?',
      'Are you sure you want to delete this comment?',
    );

    if (!shouldDelete) return;

    try {
      await Supabase.instance.client
          .from('comments')
          .delete()
          .eq('id', commentId);

      if (mounted) {
        _fetchComments(); // Refresh comments
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
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

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (widget.post['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Post ID missing')));
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final payload = {
        'post_id': widget.post['id'],
        'user_id': user.id,
        'content': text,
        'parent_id': _replyingTo?['id'], 
        'reply_to_comment_id': _replyingTo?['id'],
      };

      final response = await Supabase.instance.client
          .from('comments')
          .insert(payload)
          .select()
          .single();

      final newComment = response;
      final profileResponse = await Supabase.instance.client.from('profiles').select().eq('id', user.id).single();
      
      final fullComment = {
        ...newComment,
        'username': profileResponse['username'],
        'avatar_url': profileResponse['avatar_url'],
      };

      if (mounted) {
        setState(() {
          // Add to list and re-sort/organize? 
          // Simple insert: if replying, insert after parent/siblings. If root, append.
          // For simplicity, just append to _comments and reload or naive insert.
          // Naive: Just re-fetch to be safe or append to bottom.
          // Let's re-fetch for correct order or just append.
          // If I append a reply to bottom, it looks weird.
          // Let's Re-fetch to guarantee order.
          _fetchComments(); 
          
          _commentController.clear();
          _replyingTo = null; // Clear reply state
        });
      }

    } catch (e) {
      debugPrint("Error sending comment: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  
  // Helper for Time Ago
  String _timeAgo(String dateString) {
    if (dateString.isEmpty) return '';
    final created = DateTime.parse(dateString).toLocal();
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb = kIsWeb;
    final accent = AurbitWebTheme.accentPrimary;

    // Use AurbitWebTheme for web
    final textColor = isWeb ? (isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText) : (isDark ? Colors.white : Colors.black);
    final secondaryTextColor = isWeb ? (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext) : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
    final cardColor = isWeb ? (isDark ? AurbitWebTheme.darkCard : AurbitWebTheme.lightCard) : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isWeb ? (isDark ? AurbitWebTheme.darkBorder : AurbitWebTheme.lightBorder) : (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final bgColor = isWeb ? (isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg) : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isWeb ? null : AppBar(
        title: Text('Post', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: isWeb 
          ? _buildWebLayout(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, accent, bgColor)
          : _buildMobileBody(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, accent, bgColor),
    );
  }

  Widget _buildMobileBody(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, Color cardColor, Color borderColor, Color accent, Color bgColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostCard(isDark, cardColor, borderColor, textColor, secondaryTextColor, context),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 20, color: textColor),
                    const SizedBox(width: 8),
                    Text(
                      'Comments', 
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCommentList(),
                const SizedBox(height: 80), 
              ],
            ),
          ),
        ),
        _buildBottomInput(isDark, textColor, secondaryTextColor, borderColor, bgColor),
      ],
    );
  }

  Widget _buildWebLayout(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, Color cardColor, Color borderColor, Color accent, Color bgColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool showSidebar = screenWidth >= 1100;
    final bool isSmallScreen = screenWidth <= 800;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Center)
        Expanded(
          flex: 7,
          child: Column(
            children: [
              // Top navigation replacement for appbar on web
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 32, vertical: 16),
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
                    Text('Post Details', style: GoogleFonts.outfit(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w700, color: textColor)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPostCard(isDark, cardColor, borderColor, textColor, secondaryTextColor, context),
                          const SizedBox(height: 32),
                          _buildCommentSectionHeader(textColor),
                          const SizedBox(height: 20),
                          _buildCommentList(),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Input for web (docked at the very bottom of the center column)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildBottomInput(isDark, textColor, secondaryTextColor, borderColor, bgColor),
                ),
              ),
            ],
          ),
        ),

        // Right Sidebar
        if (showSidebar)
          Container(
            width: 340,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
              color: isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightSidebar,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildWebRightSidebar(isDark, cardColor, borderColor, textColor, secondaryTextColor, accent),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentSectionHeader(Color textColor) {
    return Row(
      children: [
        Icon(Icons.forum_outlined, size: 22, color: textColor),
        const SizedBox(width: 10),
        Text(
          'Discussion', 
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)
        ),
      ],
    );
  }

  Widget _buildWebRightSidebar(bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryTextColor, Color accent) {
    final username = widget.post['username'] ?? 'User';
    final isAnon = widget.post['is_anonymous'] == true || username == 'Anonymous';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author Card
        _sidebarCard(
          'About Author',
          isAnon ? 'The author chose to stay anonymous for this post.' : 'Contributing to the Aurbit community since ${_timeAgo(widget.post['created_at'] ?? DateTime.now().toString())}.',
          isDark, cardColor, borderColor, textColor, secondaryTextColor,
          buttonLabel: isAnon ? null : 'View Profile',
          onBtnTap: isAnon ? null : () {
             final userId = widget.post['user_id'];
             if (userId != null) {
               Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)));
             }
          }
        ),
        const SizedBox(height: 24),
        
        // Post Stats
        _sidebarCard(
          'Post Stats',
          '• ${_relateCount + _notAloneCount} Reactions\n• ${_rootComments.length} Root Comments\n• Mindful Content Checked',
          isDark, cardColor, borderColor, textColor, secondaryTextColor,
        ),
        const SizedBox(height: 24),

        // Community Guidelines (Standard)
        _sidebarCard(
          'Mindful Guidelines',
          '1. Be kind and respectful.\n2. We value authenticity.\n3. Harassment is not tolerated.\n4. Protect your privacy.',
          isDark, cardColor, borderColor, textColor, secondaryTextColor,
        ),
      ],
    );
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
          Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          Text(content, style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.6)),
          if (buttonLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBtnTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AurbitWebTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(buttonLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInput(bool isDark, Color textColor, Color secondaryTextColor, Color borderColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ]
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply Indicator
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 16, color: secondaryTextColor),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to ${_replyingTo!['username']}',
                      style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _replyingTo = null),
                      child: Icon(Icons.close, size: 16, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.transparent : Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: GoogleFonts.inter(color: textColor),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                        hintStyle: GoogleFonts.inter(color: secondaryTextColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey[400] : Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _isSending ? null : _addComment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Refactored PostCard to keep build clean
  Widget _buildPostCard(bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryTextColor, BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnPost = currentUserId == widget.post['user_id'];

    return GestureDetector(
      onLongPress: isOwnPost ? _deletePost : null,
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.post['is_anonymous'] == true || widget.post['username'] == 'Anonymous') return;
                    
                    final userId = widget.post['user_id'];
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
                      _buildAvatar(widget.post['avatar_url'], 40, isDark),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UsernameWithBadge(
                            username: widget.post['username'],
                            isVerified: (widget.post['isVerified'] as bool?) ?? false,
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                            badgeSize: 14,
                            badgeColor: const Color(0xFF1DA1F2),
                          ),
                          Text(
                            widget.post['timeAgo'],
                            style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 12),
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
                  child: Text(
                    widget.post['mood'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            Text(
              widget.post['content'],
              style: GoogleFonts.inter(fontSize: 15, height: 1.4, color: textColor).copyWith(
                fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
              ),

            ),
            const SizedBox(height: 16),
            // Chips
            Row(
              children: [
                _buildActionChip(
                  'I relate', 
                  _relateCount, 
                  context, 
                  isActive: _isRelateActive,
                  onTap: () => _toggleReaction('i_relate'),
                ),
                const SizedBox(width: 12),
                _buildActionChip(
                  "You're not alone", 
                  _notAloneCount, 
                  context, 
                  isActive: _isNotAloneActive,
                  onTap: () => _toggleReaction('youre_not_alone'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    if (_isLoadingComments) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    }

    if (_rootComments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('No comments yet. Be the first!', style: GoogleFonts.inter(color: Colors.grey)),
      );
    }

    return Column(
      children: _rootComments.map((root) {
        final rootId = root['id'] as String;
        final replies = _repliesMap[rootId] ?? [];
        return ResponseChainWidget(
          root: root,
          replies: replies,
          isDark: Theme.of(context).brightness == Brightness.dark,
          onReplyTap: (comment) {
             setState(() {
                _replyingTo = comment;
             });
             _focusNode.requestFocus();
          },
          onDeleteTap: (commentId, userId) => _deleteComment(commentId, userId),
        );
      }).toList(),
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
            : Icon(Icons.person_outline, color: isDark ? Colors.white : Colors.grey[800], size: size * 0.6),
      ),
    );
  }

  Widget _buildActionChip(String label, int count, BuildContext context, {bool isActive = false, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Active colors
    final activeBgColor = isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1);
    final activeTextColor = isDark ? Colors.blue[200] : Colors.blue[700];
    final activeBorderColor = isDark ? Colors.blue[700]! : Colors.blue[200]!;

    // Inactive colors
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

}

class ResponseChainWidget extends StatefulWidget {
  final Map<String, dynamic> root;
  final List<Map<String, dynamic>> replies;
  final bool isDark;
  final Function(Map<String, dynamic>) onReplyTap;
  final Function(String, String) onDeleteTap;

  const ResponseChainWidget({
    super.key,
    required this.root,
    required this.replies,
    required this.isDark,
    required this.onReplyTap,
    required this.onDeleteTap,
  });

  @override
  State<ResponseChainWidget> createState() => _ResponseChainWidgetState();
}

class _ResponseChainWidgetState extends State<ResponseChainWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Determine which replies to show
    List<Map<String, dynamic>> visibleReplies = widget.replies;
    bool showExpandButton = false;

    if (!_isExpanded && widget.replies.length > 2) {
      visibleReplies = widget.replies.take(2).toList();
      showExpandButton = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Root Comment
        SingleCommentWidget(
          comment: widget.root,
          isDark: widget.isDark,
          isReply: false,
          onReplyTap: widget.onReplyTap,
          onDeleteTap: widget.onDeleteTap,
        ),

        // Replies
        ...visibleReplies.map((reply) => SingleCommentWidget(
          comment: reply,
          isDark: widget.isDark,
          isReply: true,
          onReplyTap: widget.onReplyTap,
          onDeleteTap: widget.onDeleteTap,
        )),

        // Expand Button
        if (showExpandButton)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = true),
              child: Text(
                'Show all comments', // Or "Show ${widget.replies.length - 2} more replies"
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SingleCommentWidget extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isDark;
  final bool isReply;
  final Function(Map<String, dynamic>) onReplyTap;
  final Function(String, String) onDeleteTap;

  const SingleCommentWidget({
    super.key,
    required this.comment,
    required this.isDark,
    required this.isReply,
    required this.onReplyTap,
    required this.onDeleteTap,
  });

  String _timeAgo(String dateString) {
    if (dateString.isEmpty) return '';
    final created = DateTime.parse(dateString).toLocal();
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    
    final int depth = comment['depth'] ?? 0;
    // Cap visual depth to avoid overflow
    final int visualDepth = depth > 4 ? 4 : depth;
    final double indentWidth = 16.0; // Slightly tighter indentation for lines
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnComment = currentUserId == comment['user_id'];

    return GestureDetector(
      onLongPress: isOwnComment ? () => onDeleteTap(comment['id'], comment['user_id']) : null,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Spacers for higher depths (Grandparent levels)
              if (visualDepth > 1)
                SizedBox(width: (visualDepth - 1) * indentWidth),

              // 2. Connector Line for current level (Parent to Child)
              if (visualDepth > 0)
               Container(
                 width: indentWidth,
                 alignment: Alignment.topLeft,
                 child: CustomPaint(
                   size: const Size(16, double.infinity),
                   painter: _ResponseChainPainter(isDark: isDark),
                 ),
               ),
               
               // Extra spacing if nested to separate line from avatar slightly
               if (visualDepth > 0) const SizedBox(width: 4),

              // 3. The Content (Avatar + Text)
              GestureDetector(
                onTap: () {
                  final userId = comment['user_id'];
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(userId: userId),
                      ),
                    );
                  }
                },
                child: _buildAvatar(comment['avatar_url'], visualDepth > 0 ? 28 : 32, isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // ... (Content Bubble)
                     Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(12).copyWith(topLeft: Radius.zero),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final userId = comment['user_id'];
                              if (userId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(userId: userId),
                                  ),
                                );
                              }
                            },
                            child: UsernameWithBadge(
                              username: comment['username'] ?? 'User',
                              isVerified: (comment['isVerified'] as bool?) ?? false,
                              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                              badgeSize: 13,
                              badgeColor: const Color(0xFF1DA1F2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment['content'] ?? '',
                            style: GoogleFonts.inter(fontSize: 14, color: textColor, height: 1.3).copyWith(
                              fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                            ),

                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Footer
                    Row(
                      children: [
                        Text(
                          _timeAgo(comment['created_at'] ?? ''),
                          style: GoogleFonts.inter(fontSize: 11, color: secondaryTextColor),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => onReplyTap(comment),
                          child: Text(
                            'Reply',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.blue[300] : Colors.blue[700]),
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
            : Icon(Icons.person_outline, color: isDark ? Colors.white : Colors.grey[800], size: size * 0.6),
      ),
    );
  }
}

class _ResponseChainPainter extends CustomPainter {
  final bool isDark;
  _ResponseChainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.grey[700]! : Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    // Start from top center (connecting from parent above)
    // Actually, usually it connects from Top-Left or Top-Center depending on parent alignment.
    // Let's draw a curve '└'.
    // Start top - slightly left? No, let's assume vertical line comes from top-center of this width slot.
    
    double centerX = size.width / 2;
    // Vertical line from top
    path.moveTo(centerX, -10); // Start slightly above to ensure connection
    path.lineTo(centerX, size.height * 0.4); // Go down to roughly avatar center height
    
    // Horizontal line to right (to avatar)
    path.quadraticBezierTo(centerX, size.height * 0.6, size.width, size.height * 0.6);
    // Or just simple L
    // path.lineTo(size.width, size.height * 0.4);

    // To make it look like a smooth tree, often a simple quarter-circle arc is used.
    // Move to Top-Center
    // Line to (Center, Center - radius)
    // Arc to (Center + radius, Center)
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
