import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common/user_avatar.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _db = SupabaseService.instance;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<PostCommentModel> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final data = await _db.client
          .from(AppConstants.postCommentsTable)
          .select('*, profiles!post_comments_user_id_fkey(*)')
          .eq('post_id', widget.post.id)
          .isFilter('reply_to_id', null)
          .order('created_at', ascending: true)
          .limit(100);

      final comments = <PostCommentModel>[];
      for (final item in data) {
        final c = PostCommentModel.fromJson(item);
        if (item['profiles'] != null) c.author = UserModel.fromJson(item['profiles']);
        comments.add(c);
      }
      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    setState(() => _posting = true);
    try {
      await _db.client.from(AppConstants.postCommentsTable).insert({
        'post_id': widget.post.id,
        'user_id': userId,
        'content': text,
        'likes_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      _commentCtrl.clear();
      await _loadComments();
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post.author;

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                // Post content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(user: author, displayName: author?.displayName ?? 'U', radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                author?.displayName ?? 'Unknown',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (author?.isVerified == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, color: AppColors.accent, size: 14),
                              ],
                            ],
                          ),
                          Text('@${author?.username ?? ''} · ${timeago.format(post.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 17),
                ),
                if (post.mediaUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(post.mediaUrl!, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${post.likesCount} likes', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 16),
                    Text('${post.commentsCount} comments', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const Divider(height: 24),
                // Comments
                if (_loading)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No comments yet. Be the first!',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  )
                else
                  ..._comments.map((c) => _CommentTile(comment: c)),
              ],
            ),
          ),
          // Comment input
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: const BoxDecoration(
              color: AppColors.darkCard,
              border: Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.darkElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _posting ? null : _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostCommentModel comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(user: comment.author, displayName: comment.author?.displayName ?? 'U', radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.author?.displayName ?? 'Unknown',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        comment.content,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(comment.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
