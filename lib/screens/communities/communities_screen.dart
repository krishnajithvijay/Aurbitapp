import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/community_model.dart';
import '../../widgets/common/user_avatar.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> with SingleTickerProviderStateMixin {
  final _db = SupabaseService.instance;
  late final TabController _tabs;
  final List<CommunityModel> _myComms = [];
  final List<CommunityModel> _discover = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadCommunities();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      // All communities
      final allData = await _db.client
          .from(AppConstants.communitiesTable)
          .select()
          .order('member_count', ascending: false);

      // My memberships
      final memberData = await _db.client
          .from(AppConstants.communityMembersTable)
          .select('community_id')
          .eq('user_id', userId);
      final myIds = memberData.map((e) => e['community_id'] as String).toSet();

      final all = allData.map((e) {
        final c = CommunityModel.fromJson(e);
        return c.copyWith(isJoined: myIds.contains(c.id));
      }).toList();

      setState(() {
        _myComms
          ..clear()
          ..addAll(all.where((c) => c.isJoined));
        _discover
          ..clear()
          ..addAll(all.where((c) => !c.isJoined));
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleJoin(CommunityModel community) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    if (community.isJoined) {
      await _db.client
          .from(AppConstants.communityMembersTable)
          .delete()
          .eq('community_id', community.id)
          .eq('user_id', userId);
    } else {
      await _db.client.from(AppConstants.communityMembersTable).insert({
        'community_id': community.id,
        'user_id': userId,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });
    }
    _loadCommunities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(
        title: const Text('Communities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
              );
              if (created == true) _loadCommunities();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'My Communities'), Tab(text: 'Discover')],
        ),
      ),
      body: _loading
          ? _shimmer()
          : TabBarView(
              controller: _tabs,
              children: [
                _buildList(_myComms, showJoined: true),
                _buildList(_discover, showJoined: false),
              ],
            ),
    );
  }

  Widget _buildList(List<CommunityModel> list, {required bool showJoined}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              showJoined ? 'No communities joined yet' : 'No communities to discover',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadCommunities,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _CommunityCard(
          community: list[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CommunityDetailScreen(community: list[i])),
          ),
          onJoin: () => _toggleJoin(list[i]),
        ),
      ),
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkElevated,
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;
  final VoidCallback onJoin;
  const _CommunityCard({required this.community, required this.onTap, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: community.avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(community.avatarUrl!, fit: BoxFit.cover),
                      )
                    : Center(
                        child: Text(
                          community.name.isNotEmpty ? community.name[0].toUpperCase() : 'C',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${community.memberCount} members',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (community.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        community.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onJoin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: community.isJoined ? AppColors.textMuted : AppColors.primary,
                  side: BorderSide(
                    color: community.isJoined ? AppColors.darkBorder : AppColors.primary,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  community.isJoined ? 'Joined' : 'Join',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
