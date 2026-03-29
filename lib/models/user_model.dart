class UserModel {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? publicKey;
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.publicKey,
    this.isVerified = false,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      publicKey: json['public_key'],
      isVerified: json['is_verified'] ?? false,
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen']) : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'public_key': publicKey,
        'is_verified': isVerified,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      publicKey: publicKey,
      isVerified: isVerified,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}
