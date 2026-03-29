import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../widgets/feed/post_card.dart';
import '../notifications/notifications_screen.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _db = SupabaseService.instance;
  final _scrollCtrl = ScrollController();
  final List<PostModel> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = AppConstants.feedPageSize;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _posts.clear();
        _offset = 0;
        _hasMore = true;
        _loading = true;
      });
    }
    try {
      final data = await _db.client
          .from(AppConstants.postsTable)
          .select('*, profiles!posts_user_id_fkey(*)')
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final userId = AuthService.instance.currentUserId;
      final posts = <PostModel>[];

      for (final item in data) {
        final post = PostModel.fromJson(item);
        if (item['profiles'] != null) {
          post.author = UserModel.fromJson(item['profiles']);
        }
        // Check if liked
        if (userId != null) {
          final liked = await _db.client
              .from(AppConstants.postLikesTable)
              .select('id')
              .eq('post_id', post.id)
              .eq('user_id', userId)
              .maybeSingle();
          posts.add(post.copyWith(isLiked: liked != null));
        } else {
          posts.add(post);
        }
      }

      setState(() {
        _posts.addAll(posts);
        _offset += posts.length;
        _hasMore = posts.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    await _loadPosts();
    setState(() => _loadingMore = false);
  }

  Future<void> _toggleLike(PostModel post) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx == -1) return;

    // Optimistic UI
    final wasLiked = post.isLiked;
    setState(() {
      _posts[idx] = post.copyWith(
        isLiked: !wasLiked,
        likesCount: wasLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    });

    try {
      if (wasLiked) {
        await _db.client
            .from(AppConstants.postLikesTable)
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', userId);
      } else {
        await _db.client.from(AppConstants.postLikesTable).insert({
          'post_id': post.id,
          'user_id': userId,
        });
      }
    } catch (_) {
      // Rollback
      if (mounted) {
        setState(() {
          _posts[idx] = post.copyWith(isLiked: wasLiked, likesCount: post.likesCount);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: NestedScrollView(
        controller: _scrollCtrl,
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.oledBlack,
            scrolledUnderElevation: 0,
            title: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'Aurbit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ],
          ),
        ],
        body: _loading
            ? _buildShimmer()
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.darkCard,
                onRefresh: () => _loadPosts(refresh: true),
                child: _posts.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _posts.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 1),
                        itemBuilder: (ctx, i) {
                          if (i >= _posts.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }
                          return PostCard(
                            post: _posts[i],
                            onLike: () => _toggleLike(_posts[i]),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          if (created == true) _loadPosts(refresh: true);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkElevated,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
          height: 200,
          color: AppColors.darkCard,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.dynamic_feed_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No posts yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Be the first to post!', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
