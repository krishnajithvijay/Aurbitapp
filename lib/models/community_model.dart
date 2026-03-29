import 'user_model.dart';

class CommunityModel {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final String createdBy;
  final int memberCount;
  final int postCount;
  final bool isJoined;
  final bool isPrivate;
  final List<String> tags;
  final DateTime createdAt;

  CommunityModel({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    required this.createdBy,
    this.memberCount = 0,
    this.postCount = 0,
    this.isJoined = false,
    this.isPrivate = false,
    this.tags = const [],
    required this.createdAt,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      avatarUrl: json['avatar_url'],
      bannerUrl: json['banner_url'],
      createdBy: json['created_by'] ?? '',
      memberCount: json['member_count'] ?? 0,
      postCount: json['post_count'] ?? 0,
      isJoined: json['is_joined'] ?? false,
      isPrivate: json['is_private'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'created_by': createdBy,
        'is_private': isPrivate,
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
      };

  CommunityModel copyWith({bool? isJoined, int? memberCount}) {
    return CommunityModel(
      id: id,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      createdBy: createdBy,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount,
      isJoined: isJoined ?? this.isJoined,
      isPrivate: isPrivate,
      tags: tags,
      createdAt: createdAt,
    );
  }
}

enum OrbitStatus { pending, accepted, blocked }

class OrbitModel {
  final String id;
  final String requesterId;
  final String addresseeId;
  final OrbitStatus status;
  final DateTime createdAt;
  UserModel? user;

  OrbitModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.user,
  });

  factory OrbitModel.fromJson(Map<String, dynamic> json) {
    return OrbitModel(
      id: json['id'] ?? '',
      requesterId: json['requester_id'] ?? '',
      addresseeId: json['addressee_id'] ?? '',
      status: OrbitStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => OrbitStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String? actorId;
  final String? title;
  final String? body;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  UserModel? actor;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.actorId,
    this.title,
    this.body,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
    this.actor,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] ?? 'system',
      actorId: json['actor_id'],
      title: json['title'],
      body: json['body'],
      referenceId: json['reference_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get icon {
    switch (type) {
      case 'like': return '❤️';
      case 'comment': return '💬';
      case 'orbit_request': return '🪐';
      case 'orbit_accepted': return '✅';
      case 'message': return '📩';
      case 'mention': return '@';
      default: return '🔔';
    }
  }
}
