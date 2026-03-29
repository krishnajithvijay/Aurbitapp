import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/community_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common/user_avatar.dart';
import '../../screens/profile/user_profile_screen.dart';

class OrbitScreen extends StatefulWidget {
  const OrbitScreen({super.key});

  @override
  State<OrbitScreen> createState() => _OrbitScreenState();
}

class _OrbitScreenState extends State<OrbitScreen> with SingleTickerProviderStateMixin {
  final _db = SupabaseService.instance;
  late final TabController _tabs;
  final List<OrbitModel> _friends = [];
  final List<OrbitModel> _requests = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final List<UserModel> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadOrbit();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrbit() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      // Accepted
      final accepted = await _db.client
          .from(AppConstants.orbitsTable)
          .select()
          .or('requester_id.eq.$userId,addressee_id.eq.$userId')
          .eq('status', 'accepted');

      // Pending incoming
      final pending = await _db.client
          .from(AppConstants.orbitsTable)
          .select()
          .eq('addressee_id', userId)
          .eq('status', 'pending');

      final friends = <OrbitModel>[];
      for (final item in accepted) {
        final o = OrbitModel.fromJson(item);
        final otherId = o.requesterId == userId ? o.addresseeId : o.requesterId;
        final userRow = await _db.selectSingle(AppConstants.profilesTable, column: 'id', value: otherId);
        if (userRow != null) o.user = UserModel.fromJson(userRow);
        friends.add(o);
      }

      final requests = <OrbitModel>[];
      for (final item in pending) {
        final o = OrbitModel.fromJson(item);
        final userRow = await _db.selectSingle(AppConstants.profilesTable, column: 'id', value: o.requesterId);
        if (userRow != null) o.user = UserModel.fromJson(userRow);
        requests.add(o);
      }

      setState(() {
        _friends
          ..clear()
          ..addAll(friends);
        _requests
          ..clear()
          ..addAll(requests);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendOrbitRequest(UserModel user) async {
    final myId = AuthService.instance.currentUserId;
    if (myId == null) return;
    try {
      await _db.client.from(AppConstants.orbitsTable).insert({
        'requester_id': myId,
        'addressee_id': user.id,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Orbit request sent to ${user.displayName} 🪐')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _respondToRequest(OrbitModel orbit, bool accept) async {
    await _db.client
        .from(AppConstants.orbitsTable)
        .update({'status': accept ? 'accepted' : 'blocked'}).eq('id', orbit.id);
    _loadOrbit();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    setState(() => _searching = true);
    try {
      final myId = AuthService.instance.currentUserId ?? '';
      final results = await _db.client
          .from(AppConstants.profilesTable)
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', myId)
          .limit(20);
      setState(() {
        _searchResults
          ..clear()
          ..addAll(results.map((e) => UserModel.fromJson(e)));
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(
        title: const Text('Orbit'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            const Tab(text: 'Friends'),
            Tab(text: 'Requests${_requests.isNotEmpty ? ' (${_requests.length})' : ''}'),
            const Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
          _buildDiscoverTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_loading) return _shimmer();
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪐', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Your orbit is empty', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Discover people to add to your orbit', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadOrbit,
      child: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (ctx, i) {
          final orbit = _friends[i];
          final user = orbit.user;
          if (user == null) return const SizedBox();
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.id)),
            ),
            leading: UserAvatar(user: user, radius: 24, showOnlineIndicator: true),
            title: Row(
              children: [
                Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (user.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, color: AppColors.accent, size: 14),
                ],
              ],
            ),
            subtitle: Text('@${user.username}', style: const TextStyle(color: AppColors.textMuted)),
            trailing: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(color: AppColors.darkBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: const Text('In Orbit', style: TextStyle(fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_loading) return _shimmer();
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No pending requests', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (ctx, i) {
        final orbit = _requests[i];
        final user = orbit.user;
        if (user == null) return const SizedBox();
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                UserAvatar(user: user, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('@${user.username}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _SmallBtn(
                      label: 'Accept',
                      color: AppColors.primary,
                      onTap: () => _respondToRequest(orbit, true),
                    ),
                    const SizedBox(width: 8),
                    _SmallBtn(
                      label: 'Decline',
                      color: AppColors.darkElevated,
                      onTap: () => _respondToRequest(orbit, false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _search,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name or username...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty && _searchCtrl.text.isNotEmpty
              ? Center(child: Text('No users found', style: Theme.of(context).textTheme.bodyMedium))
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) {
                    final user = _searchResults[i];
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.id)),
                      ),
                      leading: UserAvatar(user: user, radius: 22),
                      title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('@${user.username}'),
                      trailing: OutlinedButton(
                        onPressed: () => _sendOrbitRequest(user),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('+ Orbit', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkElevated,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => const ListTile(
          leading: CircleAvatar(radius: 24, backgroundColor: AppColors.darkCard),
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
