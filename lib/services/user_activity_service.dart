import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Service to track and manage user activity status
class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final _supabase = Supabase.instance.client;
  Timer? _activityTimer;
  
  /// Start tracking user activity (call when app starts or user logs in)
  void startTracking() {
    // Update immediately
    updateActivity();
    
    // Update every 2 minutes to maintain "active" status
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      updateActivity();
    });
  }
  
  /// Stop tracking (call when user logs out or app is paused)
  void stopTracking() {
    _activityTimer?.cancel();
    _activityTimer = null;
  }
  
  /// Update the current user's last active timestamp
  Future<void> updateActivity() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabase.rpc('update_user_activity');
    } catch (e) {
      // Silently fail - activity tracking shouldn't crash the app
      print('Error updating user activity: $e');
    }
  }
  
  /// Check if a specific user is currently active
  Future<bool> isUserActive(String userId) async {
    try {
      final result = await _supabase.rpc('is_user_active', params: {
        'check_user_id': userId,
      });
      return result as bool? ?? false;
    } catch (e) {
      print('Error checking user activity: $e');
      return false;
    }
  }
  
  /// Get activity status for multiple users at once
  Future<Map<String, bool>> getUsersActivityStatus(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    
    try {
      final result = await _supabase.rpc('get_users_activity_status', params: {
        'user_ids': userIds,
      }) as List<dynamic>;
      
      final Map<String, bool> statusMap = {};
      for (var item in result) {
        final userId = item['user_id'] as String;
        final isActive = item['is_active'] as bool? ?? false;
        statusMap[userId] = isActive;
      }
      
      return statusMap;
    } catch (e) {
      print('Error getting users activity status: $e');
      return {};
    }
  }
  
  /// Get count of active members in a community
  Future<int> getActiveCommunityMembers(String communityId) async {
    try {
      final result = await _supabase.rpc('get_active_community_members', params: {
        'community_id_param': communityId,
      });
      return result as int? ?? 0;
    } catch (e) {
      print('Error getting active community members: $e');
      return 0;
    }
  }
  
  /// Get total unread message count for current user
  Future<int> getUnreadMessageCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;
      
      final result = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', userId)
          .eq('is_read', false);
      
      return (result as List).length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }
}
