import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common/user_avatar.dart';
import 'chat_screen.dart';
import '../../screens/orbit/new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _db = SupabaseService.instance;
  final List<ChatModel> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToChats();
  }

  void _subscribeToChats() {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    _db.client
        .channel('chats_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.chatsTable,
          callback: (_) => _loadChats(),
        )
        .subscribe();
  }

  Future<void> _loadChats() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    try {
      final data = await _db.client
          .from(AppConstants.chatsTable)
          .select()
          .or('participant1_id.eq.$userId,participant2_id.eq.$userId')
          .order('updated_at', ascending: false);

      final chats = <ChatModel>[];
      for (final item in data) {
        final chat = ChatModel.fromJson(item);
        final otherId = chat.participant1Id == userId ? chat.participant2Id : chat.participant1Id;
        final userRow = await _db.selectSingle(AppConstants.profilesTable, column: 'id', value: otherId);
        if (userRow != null) chat.otherUser = UserModel.fromJson(userRow);

        // Get last message
        final msgData = await _db.client
            .from(AppConstants.messagesTable)
            .select()
            .eq('chat_id', chat.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (msgData != null) {
          // Note: content will be set to "[Encrypted]" until decrypted
          chats.add(ChatModel(
            id: chat.id,
            participant1Id: chat.participant1Id,
            participant2Id: chat.participant2Id,
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt,
            otherUser: chat.otherUser,
            lastMessage: MessageModel.fromJson(msgData),
          ));
        } else {
          chats.add(chat);
        }
      }
      if (mounted) {
        setState(() {
          _chats
            ..clear()
            ..addAll(chats);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const NewChatScreen()),
              );
              if (result == true) _loadChats();
            },
          ),
        ],
      ),
      body: _loading
          ? _buildShimmer()
          : _chats.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  onRefresh: _loadChats,
                  child: ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (ctx, i) => _ChatTile(
                      chat: _chats[i],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(chat: _chats[i]),
                          ),
                        );
                        _loadChats();
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkElevated,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(radius: 26, backgroundColor: AppColors.darkCard),
          title: Container(height: 14, width: 120, color: AppColors.darkCard),
          subtitle: Container(height: 12, width: 180, color: AppColors.darkCard),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No messages yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Start a conversation!', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const NewChatScreen()),
              );
              if (result == true) _loadChats();
            },
            icon: const Icon(Icons.add),
            label: const Text('New Message'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final other = chat.otherUser;
    final lastMsg = chat.lastMessage;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: UserAvatar(
        user: other,
        displayName: other?.displayName ?? 'User',
        radius: 26,
        showOnlineIndicator: true,
      ),
      title: Text(
        other?.displayName ?? 'User',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: lastMsg != null
          ? Text(
              '🔒 Encrypted message',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text('Start chatting', style: Theme.of(context).textTheme.bodySmall),
      trailing: lastMsg != null
          ? Text(
              timeago.format(lastMsg.createdAt, allowFromNow: true),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            )
          : null,
    );
  }
}
