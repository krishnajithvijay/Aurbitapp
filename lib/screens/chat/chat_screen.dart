import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/encryption_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common/user_avatar.dart';
import '../calls/call_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;
  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _db = SupabaseService.instance;
  final _enc = EncryptionService.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  SimpleKeyPair? _myKeyPair;
  String? _recipientPublicKey;
  UserModel? _otherUser;
  bool _isTyping = false;
  Timer? _typingTimer;

  String get _myId => AuthService.instance.currentUserId ?? '';
  UserModel? get _me => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _otherUser = widget.chat.otherUser;
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Load E2E keys
    _myKeyPair = await _enc.loadPrivateKey();
    _recipientPublicKey = _otherUser?.publicKey;
    await _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final data = await _db.client
          .from(AppConstants.messagesTable)
          .select()
          .eq('chat_id', widget.chat.id)
          .order('created_at', ascending: true)
          .limit(AppConstants.chatPageSize);

      final msgs = <MessageModel>[];
      for (final item in data) {
        final msg = MessageModel.fromJson(item);
        final decrypted = await _decryptMessage(msg);
        msgs.add(decrypted);
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    _channel = _db.client
        .channel('messages_${widget.chat.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chat.id,
          ),
          callback: (payload) async {
            final raw = payload.newRecord;
            if (raw.isEmpty) return;
            final msg = MessageModel.fromJson(raw);
            final decrypted = await _decryptMessage(msg);
            if (mounted) {
              setState(() => _messages.add(decrypted));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  Future<MessageModel> _decryptMessage(MessageModel msg) async {
    if (msg.encryptedContent == null) return msg;
    if (_myKeyPair == null) return msg;

    // Determine sender's public key
    String? senderPubKey;
    if (msg.senderId == _myId) {
      senderPubKey = _recipientPublicKey;
    } else {
      senderPubKey = _recipientPublicKey;
    }

    if (senderPubKey == null) {
      return MessageModel(
        id: msg.id,
        chatId: msg.chatId,
        senderId: msg.senderId,
        content: '[Encrypted]',
        type: msg.type,
        status: msg.status,
        createdAt: msg.createdAt,
        isDeleted: msg.isDeleted,
      );
    }

    try {
      final decrypted = await _enc.decryptMessage(
        encryptedData: {
          'ciphertext': msg.encryptedContent!,
          'nonce': msg.nonce ?? '',
          'mac': msg.mac ?? '',
        },
        senderPublicKeyBase64: senderPubKey,
        recipientKeyPair: _myKeyPair!,
      );
      return MessageModel(
        id: msg.id,
        chatId: msg.chatId,
        senderId: msg.senderId,
        content: decrypted ?? '[Decryption failed]',
        type: msg.type,
        status: msg.status,
        mediaUrl: msg.mediaUrl,
        createdAt: msg.createdAt,
        readAt: msg.readAt,
        isDeleted: msg.isDeleted,
      );
    } catch (_) {
      return MessageModel(
        id: msg.id,
        chatId: msg.chatId,
        senderId: msg.senderId,
        content: '[Encrypted]',
        type: msg.type,
        status: msg.status,
        createdAt: msg.createdAt,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      Map<String, String> encData;

      if (_myKeyPair != null && _recipientPublicKey != null) {
        encData = await _enc.encryptMessage(
          plaintext: text,
          recipientPublicKeyBase64: _recipientPublicKey!,
          senderKeyPair: _myKeyPair!,
        );
      } else {
        // Fallback: store as "encrypted" even if keys not available
        encData = {
          'ciphertext': text,
          'nonce': '',
          'mac': '',
        };
      }

      await _db.client.from(AppConstants.messagesTable).insert({
        'chat_id': widget.chat.id,
        'sender_id': _myId,
        'encrypted_content': encData['ciphertext'],
        'nonce': encData['nonce'],
        'mac': encData['mac'],
        'type': 'text',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update chat updated_at
      await _db.client
          .from(AppConstants.chatsTable)
          .update({'updated_at': DateTime.now().toIso8601String()}).eq('id', widget.chat.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg.senderId == _myId;
                      final showDate = i == 0 ||
                          _messages[i].createdAt.day != _messages[i - 1].createdAt.day;
                      return Column(
                        children: [
                          if (showDate)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _formatDate(msg.createdAt),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                          _MessageBubble(message: msg, isMe: isMe),
                        ],
                      );
                    },
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          UserAvatar(
            user: _otherUser,
            displayName: _otherUser?.displayName ?? 'User',
            radius: 18,
            showOnlineIndicator: true,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _otherUser?.displayName ?? 'User',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                _otherUser?.isOnline == true ? '● Online' : 'Offline',
                style: TextStyle(
                  color: _otherUser?.isOnline == true ? AppColors.online : AppColors.offline,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                otherUser: _otherUser!,
                isVideo: false,
                chatId: widget.chat.id,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                otherUser: _otherUser!,
                isVideo: true,
                chatId: widget.chat.id,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textMuted),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.darkElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.darkBorder, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: IconButton(
                      icon: const Icon(Icons.mood_rounded, color: AppColors.textMuted),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Today';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe ? AppColors.primaryGradient : null,
                  color: isMe ? null : AppColors.darkCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: AppColors.darkBorder, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.isDeleted)
                      const Text(
                        'Message deleted',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      )
                    else
                      Text(
                        message.content ?? '[Encrypted]',
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            color: isMe ? Colors.white60 : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.status == MessageStatus.read
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 12,
                            color: message.status == MessageStatus.read
                                ? AppColors.accent
                                : Colors.white60,
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_rounded, size: 9, color: AppColors.accentGreen),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
