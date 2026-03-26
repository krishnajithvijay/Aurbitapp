// Model for user orbit relationships
class UserOrbit {
  final String id;
  final String userId;
  final String friendId;
  final String orbitType; // 'inner' or 'outer'
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Optional joined profile data
  final String? friendUsername;
  final String? friendAvatarUrl;
  final bool? friendIsVerified;
  final String? friendCurrentMood;

  UserOrbit({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.orbitType,
    required this.createdAt,
    required this.updatedAt,
    this.friendUsername,
    this.friendAvatarUrl,
    this.friendIsVerified,
    this.friendCurrentMood,
  });

  factory UserOrbit.fromJson(Map<String, dynamic> json) {
    // Handle joined profile data
    final profile = json['profiles'] as Map<String, dynamic>?;
    
    return UserOrbit(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      friendId: json['friend_id']?.toString() ?? '',
      orbitType: json['orbit_type']?.toString() ?? 'outer',
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      friendUsername: profile?['username']?.toString(),
      friendAvatarUrl: profile?['avatar_url']?.toString(),
      friendIsVerified: profile?['is_verified'] as bool?,
      friendCurrentMood: profile?['current_mood']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'orbit_type': orbitType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserOrbit copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? orbitType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? friendUsername,
    String? friendAvatarUrl,
    bool? friendIsVerified,
    String? friendCurrentMood,
  }) {
    return UserOrbit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      orbitType: orbitType ?? this.orbitType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      friendUsername: friendUsername ?? this.friendUsername,
      friendAvatarUrl: friendAvatarUrl ?? this.friendAvatarUrl,
      friendIsVerified: friendIsVerified ?? this.friendIsVerified,
      friendCurrentMood: friendCurrentMood ?? this.friendCurrentMood,
    );
  }

  bool get isInnerOrbit => orbitType == 'inner';
  bool get isOuterOrbit => orbitType == 'outer';

  @override
  String toString() {
    return 'UserOrbit(id: $id, userId: $userId, friendId: $friendId, orbitType: $orbitType, friendUsername: $friendUsername)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is UserOrbit &&
      other.id == id &&
      other.userId == userId &&
      other.friendId == friendId &&
      other.orbitType == orbitType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      userId.hashCode ^
      friendId.hashCode ^
      orbitType.hashCode;
  }
}

// Orbit type enum for type safety
enum OrbitType {
  inner('inner'),
  outer('outer');

  final String value;
  const OrbitType(this.value);

  static OrbitType fromString(String value) {
    return OrbitType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrbitType.outer,
    );
  }
}
