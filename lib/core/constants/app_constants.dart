class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://cajrpwygkazwdbcoacvv.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_TiFwZVwEVCwWv2Qn-dJiNA_3Jlcq94n';

  // App info
  static const String appName = 'Aurbit';
  static const String appVersion = '1.0.0';

  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String postMediaBucket = 'post-media';
  static const String communityAvatarsBucket = 'community-avatars';

  // Supabase table names
  static const String profilesTable = 'profiles';
  static const String postsTable = 'posts';
  static const String postLikesTable = 'post_likes';
  static const String postCommentsTable = 'post_comments';
  static const String communitiesTable = 'communities';
  static const String communityMembersTable = 'community_members';
  static const String communityPostsTable = 'community_posts';
  static const String chatsTable = 'chats';
  static const String messagesTable = 'messages';
  static const String orbitsTable = 'orbits';
  static const String notificationsTable = 'notifications';
  static const String fcmTokensTable = 'fcm_tokens';
  static const String callSignalsTable = 'call_signals';

  // Realtime channels
  static const String chatChannel = 'chat';
  static const String notificationsChannel = 'notifications';
  static const String callChannel = 'calls';
  static const String presenceChannel = 'presence';

  // Pagination
  static const int feedPageSize = 20;
  static const int chatPageSize = 50;
  static const int usersPageSize = 20;

  // Timeouts
  static const int connectionTimeout = 30;
  static const int callRingTimeout = 30;
}
