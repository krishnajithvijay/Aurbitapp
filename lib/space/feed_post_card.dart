import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'post_detail_screen.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/verified_badge.dart';
import '../widgets/link_preview_card.dart';
import '../services/link_preview_service.dart';
import '../community/community_feed_screen.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class FeedPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onDelete;
  
  FeedPostCard({
    super.key, 
    required this.post,
    this.onDelete,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  int _relateCount = 0;
  int _notAloneCount = 0;
  bool _isRelateActive = false;
  bool _isNotAloneActive = false;

  @override
  void initState() {
    super.initState();
    _relateCount = widget.post['relateCount'] ?? 0;
    _notAloneCount = widget.post['supportCount'] ?? 0;
    _fetchReactions();
  }

  Future<void> _fetchReactions() async {
    try {
      final postId = widget.post['id'];
      if (postId == null) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;

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

    setState(() {
      if (isRelate) {
        if (_isRelateActive) {
          _relateCount--;
          _isRelateActive = false;
        } else {
          _relateCount++;
          _isRelateActive = true;
          if (_isNotAloneActive) {
            _notAloneCount--;
            _isNotAloneActive = false;
          }
        }
      } else {
        if (_isNotAloneActive) {
          _notAloneCount--;
          _isNotAloneActive = false;
        } else {
          _notAloneCount++;
          _isNotAloneActive = true;
          if (_isRelateActive) {
            _relateCount--;
            _isRelateActive = false;
          }
        }
      }
    });

    try {
      if (wasActive) {
        await Supabase.instance.client.from('post_reactions').delete().match({
          'user_id': user.id,
          'post_id': postId,
          'reaction_type': type,
        });
      } else {
        if (otherWasActive) {
           await Supabase.instance.client.from('post_reactions').delete().match({
            'user_id': user.id,
            'post_id': postId,
            'reaction_type': isRelate ? 'youre_not_alone' : 'i_relate',
          });
        }
        await Supabase.instance.client.from('post_reactions').insert({
          'user_id': user.id,
          'post_id': postId,
          'reaction_type': type,
        });
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      if (mounted) {
         _fetchReactions();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update reaction')));
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
        widget.onDelete?.call();
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

  Future<void> _openCommunityFromHandle() async {
    final handle = widget.post['community_username']?.toString();
    if (handle == null || handle.isEmpty) return;

    try {
      final community = await Supabase.instance.client
          .from('communities')
          .select('*')
          .eq('username', handle)
          .maybeSingle();

      if (!mounted) return;

      if (community == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community not found')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityFeedScreen(
            community: Map<String, dynamic>.from(community),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open community')),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
        content: Text(message, style: GoogleFonts.inter(fontSize: 14, color: secondaryTextColor, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: secondaryTextColor, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb || MediaQuery.of(context).size.width >= 650;
    // Use design tokens on web, default theme colors on mobile
    final textColor = isDesktop
        ? (isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText)
        : (isDark ? Colors.white : Colors.black);
    final secondaryTextColor = isDesktop
        ? (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext)
        : (isDark ? Colors.grey[400] : Colors.grey[600]);
    final cardColor = isDesktop
        ? (isDark ? AurbitWebTheme.darkCard    : AurbitWebTheme.lightCard)
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isDesktop
        ? (isDark ? AurbitWebTheme.darkBorder  : AurbitWebTheme.lightBorder)
        : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnPost = currentUserId == widget.post['user_id'];

    return isDesktop
        ? _buildWebCard(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, isOwnPost)
        : _buildMobileCard(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, isOwnPost);
  }

  // ─── Screenshot-style Web Card ─────────────────────────────────────────────
  Widget _buildWebCard(BuildContext context, bool isDark, Color textColor, Color? secondary, Color cardColor, Color borderColor, bool isOwnPost) {
    final accentColor = const Color(0xFF7C3AED);
    final pillBg      = isDark ? const Color(0xFF252530) : const Color(0xFFF1F3F5);
    final moodLabel   = widget.post['mood'] ?? 'Neutral';
    final moodEmoji   = widget.post['moodEmoji'] ?? '😐';
    final hasImage    = (widget.post['image_url'] as String?)?.isNotEmpty == true;
    final rawContent  = widget.post['content']?.toString() ?? '';
    final displayContent = LinkPreviewService.stripUrls(rawContent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post)),
        ).then((_) => _fetchReactions()),
        onLongPress: isOwnPost ? _deletePost : null,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Top row: avatar + meta + mood pill ──────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Rounded-square avatar
                    GestureDetector(
                      onTap: () => _navigateToProfile(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 36, height: 36,
                          child: _buildAvatarInner(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Username + community
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToProfile(context),
                            child: UsernameWithBadge(
                              username: widget.post['username'] ?? 'User',
                              isVerified: (widget.post['isVerified'] as bool?) ?? false,
                              textStyle: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              badgeSize: 13,
                              badgeColor: const Color(0xFF1DA1F2),
                            ),
                          ),
                          GestureDetector(
                            onTap: (widget.post['community_username'] != null &&
                                    widget.post['community_username'].toString().isNotEmpty)
                                ? _openCommunityFromHandle
                                : null,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(fontSize: 11, color: secondary),
                                children: [
                                  const TextSpan(text: 'posted in '),
                                  TextSpan(
                                    text: (widget.post['community_username'] != null &&
                                            widget.post['community_username'].toString().isNotEmpty)
                                        ? 'c/${widget.post['community_username']}'
                                        : '${widget.post['username'] ?? 'User'}/public',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: '  •  ${widget.post['timeAgo'] ?? ''}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Post content ─────────────────────────────────────────
                Text(
                  displayContent,
                  style: GoogleFonts.inter(
                    fontSize: hasImage ? 17 : 15,
                    fontWeight: hasImage ? FontWeight.w800 : FontWeight.w500,
                    height: 1.4,
                    color: textColor,
                  ),
                  maxLines: hasImage ? 4 : 8,
                  overflow: TextOverflow.ellipsis,
                ),

                // ── Optional image ────────────────────────────────────────
                if (hasImage) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        widget.post['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Link preview (if content contains a URL) ────────────
                  Builder(builder: (context) {
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
                  }),
                ],

                const SizedBox(height: 14),

                // ── Bottom action row ─────────────────────────────────────
                Row(
                  children: [
                    // Reactions pill: ❤ count + 💎 reaction
                    Container(
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Heart
                          GestureDetector(
                            onTap: () => _toggleReaction('i_relate'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 16,
                                color: _isRelateActive ? Colors.deepOrange : (isDark ? Colors.grey[500] : Colors.grey[500]),
                              ),
                            ),
                          ),
                          Text(
                            '$_relateCount',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: _isRelateActive ? Colors.deepOrange : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                          // Divider
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(width: 1, height: 14, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                          ),
                          // Support reaction
                          GestureDetector(
                            onTap: () => _toggleReaction('youre_not_alone'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                              child: Icon(
                                Icons.handshake_rounded,
                                size: 16,
                                color: _isNotAloneActive ? Colors.blue : (isDark ? Colors.grey[500] : Colors.grey[500]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Comments button
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 15,
                                color: isDark ? Colors.grey[500] : Colors.grey[600]),
                            const SizedBox(width: 5),
                            Text('Comment',
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Share
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: pillBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.share_outlined, size: 15,
                            color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                    ),

                    if (isOwnPost) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _deletePost,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInner(bool isDark) {
    final bg = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    if (widget.post['avatar_url'] != null) {
      final url = widget.post['avatar_url'].toString();
      if (url.contains('.svg') || url.contains('dicebear')) {
        return SvgPicture.network(url, fit: BoxFit.cover);
      }
      return Image.network(url, fit: BoxFit.cover);
    }
    return Container(
      color: bg,
      child: Icon(Icons.person_outline, color: isDark ? Colors.white : Colors.grey[800], size: 18),
    );
  }

  // ─── Mobile Card (unchanged look) ─────────────────────────────────────────
  Widget _buildMobileCard(BuildContext context, bool isDark, Color textColor, Color? secondary, Color cardColor, Color borderColor, bool isOwnPost) {
    final rawContent = widget.post['content']?.toString() ?? '';
    final displayContent = LinkPreviewService.stripUrls(rawContent);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)),
        ).then((_) => _fetchReactions());
      },
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(isDark, size: 40),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UsernameWithBadge(
                            username: widget.post['username'] ?? 'User',
                            isVerified: (widget.post['isVerified'] as bool?) ?? false,
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                            badgeSize: 14,
                            badgeColor: const Color(0xFF1DA1F2),
                          ),
                          Text(
                            widget.post['timeAgo'] ?? '',
                            style: GoogleFonts.inter(color: secondary, fontSize: 12),
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
                      Text(widget.post['moodEmoji'] ?? '', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(widget.post['mood'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: secondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              displayContent,
              style: GoogleFonts.inter(fontSize: 15, height: 1.4, color: textColor),
            ),
            Builder(
              builder: (context) {
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
                _buildActionChip('I relate', _relateCount, context, isActive: _isRelateActive, onTap: () => _toggleReaction('i_relate')),
                const SizedBox(width: 12),
                _buildActionChip("You're not alone", _notAloneCount, context, isActive: _isNotAloneActive, onTap: () => _toggleReaction('youre_not_alone')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    if (widget.post['is_anonymous'] == true || widget.post['username'] == 'Anonymous') return;
    final userId = widget.post['user_id'];
    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(userId: userId, initialAvatarUrl: widget.post['avatar_url']),
        ),
      );
    }
  }

  Widget _buildAvatar(bool isDark, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: widget.post['avatar_url'] != null
            ? (widget.post['avatar_url'].toString().contains('.svg') || widget.post['avatar_url'].toString().contains('dicebear'))
                ? SvgPicture.network(widget.post['avatar_url'], fit: BoxFit.cover)
                : Image.network(widget.post['avatar_url'], fit: BoxFit.cover)
            : Icon(Icons.person_outline, color: isDark ? Colors.white : Colors.grey[800], size: size * 0.5),
      ),
    );
  }

  Widget _buildWebActionButton({
    required IconData icon,
    required String label,
    required bool isDark,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final color = isDestructive
        ? Colors.red.withOpacity(0.8)
        : (isDark ? Colors.grey[500]! : Colors.grey[600]!);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: isActive ? activeTextColor : inactiveTextColor, fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Text(count.toString(), style: GoogleFonts.inter(fontSize: 12, color: isActive ? activeTextColor : (isDark ? Colors.grey[400] : Colors.grey[500]), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
