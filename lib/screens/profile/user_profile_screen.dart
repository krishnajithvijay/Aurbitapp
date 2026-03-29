import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/community_model.dart';
import '../../models/message_model.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/feed/post_card.dart';
import '../chat/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _db = SupabaseService.instance;
  UserModel? _user;
  final List<PostModel> _posts = [];
  bool _loading = true;
  bool _inOrbit = false;
  bool _requestPending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userRow = await _db.selectSingle(AppConstants.profilesTable, column: 'id', value: widget.userId);
      if (userRow == null) { setState(() => _loading = false); return; }
      _user = UserModel.fromJson(userRow);

      final postsData = await _db.client
          .from(AppConstants.postsTable)
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(20);
      _posts
        ..clear()
        ..addAll(postsData.map((e) => PostModel.fromJson(e)..author = _user));

      // Orbit status
      final myId = AuthService.instance.currentUserId ?? '';
      final orbitRow = await _db.client
          .from(AppConstants.orbitsTable)
          .select()
          .or('and(requester_id.eq.$myId,addressee_id.eq.${widget.userId}),and(requester_id.eq.${widget.userId},addressee_id.eq.$myId)')
          .maybeSingle();
      if (orbitRow != null) {
        _inOrbit = orbitRow['status'] == 'accepted';
        _requestPending = orbitRow['status'] == 'pending';
      }

      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendOrbitRequest() async {
    final myId = AuthService.instance.currentUserId;
    if (myId == null) return;
    await _db.client.from(AppConstants.orbitsTable).insert({
      'requester_id': myId,
      'addressee_id': widget.userId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    setState(() => _requestPending = true);
  }

  Future<void> _startChat() async {
    final myId = AuthService.instance.currentUserId!;
    final existing = await _db.client
        .from(AppConstants.chatsTable)
        .select()
        .or('and(participant1_id.eq.$myId,participant2_id.eq.${widget.userId}),and(participant1_id.eq.${widget.userId},participant2_id.eq.$myId)')
        .maybeSingle();

    ChatModel chat;
    if (existing != null) {
      chat = ChatModel.fromJson(existing);
      chat.otherUser = _user;
    } else {
      final newChat = await _db.client.from(AppConstants.chatsTable).insert({
        'participant1_id': myId,
        'participant2_id': widget.userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();
      chat = ChatModel.fromJson(newChat);
      chat.otherUser = _user;
    }

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.oledBlack,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      );
    }
    if (_user == null) {
      return Scaffold(
        backgroundColor: AppColors.oledBlack,
        appBar: AppBar(),
        body: const Center(child: Text('User not found')),
      );
    }

    final isMe = widget.userId == AuthService.instance.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.oledBlack,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.8), AppColors.accent.withOpacity(0.5)],
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: UserAvatar(user: _user, radius: 40, borderColor: AppColors.oledBlack),
                      ),
                      const Spacer(),
                      if (!isMe) ...[
                        if (_inOrbit)
                          OutlinedButton.icon(
                            onPressed: _startChat,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('Message'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        else if (_requestPending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.darkElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Pending', style: TextStyle(color: AppColors.textMuted)),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _sendOrbitRequest,
                            icon: const Icon(Icons.hub_rounded, size: 16),
                            label: const Text('Add to Orbit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _user!.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (_user!.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, color: AppColors.accent, size: 18),
                            ],
                          ],
                        ),
                        Text('@${_user!.username}', style: Theme.of(context).textTheme.bodyMedium),
                        if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_user!.bio!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 12),
                        Text('${_posts.length} Posts', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
          ),
          if (_posts.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No posts yet', style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => PostCard(post: _posts[i]),
                childCount: _posts.length,
              ),
            ),
        ],
      ),
    );
  }
}
