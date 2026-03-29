import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/community_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../widgets/feed/post_card.dart';
import '../../screens/feed/create_post_screen.dart';
import '../../widgets/common/app_button.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityModel community;
  const CommunityDetailScreen({super.key, required this.community});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _db = SupabaseService.instance;
  late CommunityModel _community;
  final List<PostModel> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final data = await _db.client
          .from(AppConstants.postsTable)
          .select('*, profiles!posts_user_id_fkey(*)')
          .eq('community_id', _community.id)
          .order('created_at', ascending: false)
          .limit(50);

      final posts = <PostModel>[];
      for (final item in data) {
        final p = PostModel.fromJson(item);
        if (item['profiles'] != null) p.author = UserModel.fromJson(item['profiles']);
        posts.add(p);
      }
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.oledBlack,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.7), AppColors.accent.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.oledBlack.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            _community.name.isNotEmpty ? _community.name[0].toUpperCase() : 'C',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_community.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  if (_community.description != null) ...[
                    const SizedBox(height: 6),
                    Text(_community.description!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Stat(value: '${_community.memberCount}', label: 'Members'),
                      const SizedBox(width: 24),
                      _Stat(value: '${_community.postCount}', label: 'Posts'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_community.isJoined)
                    AppButton(
                      text: '+ Create Post',
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => CreatePostScreen(communityId: _community.id)),
                        );
                        if (created == true) _loadPosts();
                      },
                      gradient: AppColors.primaryGradient,
                      height: 44,
                    ),
                  const Divider(height: 24),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No posts yet in this community', style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => PostCard(post: _posts[i], showCommunityBadge: false),
                childCount: _posts.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
