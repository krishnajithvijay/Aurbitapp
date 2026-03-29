class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://henxsgquexgxvfwngjet.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlbnhzZ3F1ZXhneHZmd25namV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjg4NTIsImV4cCI6MjA4NDUwNDg1Mn0.qhovSln6868wGsK-7jqM9D-C2133_Gcpj-E1uX4QHg0';

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
