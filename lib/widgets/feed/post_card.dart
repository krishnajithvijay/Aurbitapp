import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../models/post_model.dart';
import '../common/user_avatar.dart';
import '../../screens/feed/post_detail_screen.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final bool showCommunityBadge;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.showCommunityBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final isOwn = post.userId == AuthService.instance.currentUserId;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ),
      child: Container(
        color: AppColors.oledBlack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                UserAvatar(
                  user: author,
                  displayName: author?.displayName ?? 'User',
                  radius: 20,
                  showOnlineIndicator: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            author?.displayName ?? 'Unknown',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (author?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: AppColors.accent, size: 14),
                          ],
                        ],
                      ),
                      Text(
                        '@${author?.username ?? 'unknown'} · ${timeago.format(post.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isOwn)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 20),
                    color: AppColors.darkCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {},
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Text(
              post.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            // Media
            if (post.mediaUrl != null && post.mediaType == 'image') ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.mediaUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 220,
                      color: AppColors.darkCard,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Actions row
            Row(
              children: [
                _ActionButton(
                  icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: post.likesCount > 0 ? '${post.likesCount}' : '',
                  color: post.isLiked ? AppColors.accentPink : AppColors.textMuted,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onLike?.call();
                  },
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: post.commentsCount > 0 ? '${post.commentsCount}' : '',
                  color: AppColors.textMuted,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
                  ),
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.repeat_rounded,
                  label: '',
                  color: AppColors.textMuted,
                  onTap: () {},
                ),
                const Spacer(),
                _ActionButton(
                  icon: Icons.bookmark_border_rounded,
                  label: '',
                  color: AppColors.textMuted,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: '',
                  color: AppColors.textMuted,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.darkBorder),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}
