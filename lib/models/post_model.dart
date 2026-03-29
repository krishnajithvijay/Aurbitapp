import 'user_model.dart';

class PostModel {
  final String id;
  final String userId;
  final String? communityId;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final DateTime createdAt;
  UserModel? author;

  PostModel({
    required this.id,
    required this.userId,
    this.communityId,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.author,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      communityId: json['community_id'],
      content: json['content'] ?? '',
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'community_id': communityId,
        'content': content,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': createdAt.toIso8601String(),
      };

  PostModel copyWith({int? likesCount, int? commentsCount, bool? isLiked}) {
    return PostModel(
      id: id,
      userId: userId,
      communityId: communityId,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
      author: author,
    );
  }
}

class PostCommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String? replyToId;
  final int likesCount;
  final DateTime createdAt;
  UserModel? author;

  PostCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.replyToId,
    this.likesCount = 0,
    required this.createdAt,
    this.author,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    return PostCommentModel(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      replyToId: json['reply_to_id'],
      likesCount: json['likes_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
