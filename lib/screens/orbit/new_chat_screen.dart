import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/community_model.dart';
import '../../widgets/common/user_avatar.dart';
import '../chat/chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _db = SupabaseService.instance;
  final List<UserModel> _orbitFriends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrbit();
  }

  Future<void> _loadOrbit() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    try {
      final data = await _db.client
          .from(AppConstants.orbitsTable)
          .select()
          .or('requester_id.eq.$userId,addressee_id.eq.$userId')
          .eq('status', 'accepted');

      final friends = <UserModel>[];
      for (final item in data) {
        final orbit = OrbitModel.fromJson(item);
        final otherId = orbit.requesterId == userId ? orbit.addresseeId : orbit.requesterId;
        final userRow = await _db.selectSingle(AppConstants.profilesTable, column: 'id', value: otherId);
        if (userRow != null) friends.add(UserModel.fromJson(userRow));
      }
      setState(() {
        _orbitFriends
          ..clear()
          ..addAll(friends);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startChat(UserModel user) async {
    final myId = AuthService.instance.currentUserId!;
    // Check if chat already exists
    final existing = await _db.client
        .from(AppConstants.chatsTable)
        .select()
        .or('and(participant1_id.eq.$myId,participant2_id.eq.${user.id}),and(participant1_id.eq.${user.id},participant2_id.eq.$myId)')
        .maybeSingle();

    ChatModel chat;
    if (existing != null) {
      chat = ChatModel.fromJson(existing);
      chat.otherUser = user;
    } else {
      final newChat = await _db.client.from(AppConstants.chatsTable).insert({
        'participant1_id': myId,
        'participant2_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();
      chat = ChatModel.fromJson(newChat);
      chat.otherUser = user;
    }

    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(title: const Text('New Message')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : _orbitFriends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hub_rounded, size: 56, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text('No one in your orbit yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Add people to your orbit to chat', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _orbitFriends.length,
                  itemBuilder: (ctx, i) {
                    final user = _orbitFriends[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      onTap: () => _startChat(user),
                      leading: UserAvatar(user: user, radius: 24, showOnlineIndicator: true),
                      title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('@${user.username}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    );
                  },
                ),
    );
  }
}
