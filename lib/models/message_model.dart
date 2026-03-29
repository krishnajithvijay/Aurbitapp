enum MessageType { text, image, audio, video, file, call, system }
enum MessageStatus { sending, sent, delivered, read, failed }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? content; // decrypted plaintext (local only)
  final String? encryptedContent;
  final String? nonce;
  final String? mac;
  final MessageType type;
  final MessageStatus status;
  final String? mediaUrl;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.content,
    this.encryptedContent,
    this.nonce,
    this.mac,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.mediaUrl,
    this.replyToId,
    required this.createdAt,
    this.readAt,
    this.isDeleted = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      chatId: json['chat_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      encryptedContent: json['encrypted_content'],
      nonce: json['nonce'],
      mac: json['mac'],
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      mediaUrl: json['media_url'],
      replyToId: json['reply_to_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'chat_id': chatId,
        'sender_id': senderId,
        'encrypted_content': encryptedContent,
        'nonce': nonce,
        'mac': mac,
        'type': type.name,
        'status': status.name,
        'media_url': mediaUrl,
        'reply_to_id': replyToId,
        'created_at': createdAt.toIso8601String(),
        'is_deleted': isDeleted,
      };

  bool get isMine {
    return false; // filled in at display time
  }
}

class ChatModel {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  UserModel? otherUser; // populated client-side

  ChatModel({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.otherUser,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] ?? '',
      participant1Id: json['participant1_id'] ?? '',
      participant2Id: json['participant2_id'] ?? '',
      unreadCount: json['unread_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }
}
