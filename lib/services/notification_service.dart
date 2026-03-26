import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  // Fetch all notifications for current user
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('notifications')
          .select('''
            *,
            sender:sender_id(id, username, avatar_url),
            post:post_id(id, content, mood, created_at, user_id, profiles:user_id(username, avatar_url, is_verified)),
            comment:comment_id(id, content)
          ''')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final count = await _supabase
          .from('notifications')
          .count()
          .eq('recipient_id', userId)
          .neq('is_read', true);

      return count;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Create orbit request notification
  Future<void> createOrbitRequestNotification({
    required String recipientId,
    required String orbitType, // 'inner' or 'outer'
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .single();

      await _supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': userId,
        'type': 'orbit_request',
        'orbit_type': orbitType,
        'title': '${profile['username']} sent you a friend request',
        'body': null,
      });
    } catch (e) {
      debugPrint('Error creating orbit request notification: $e');
    }
  }

  // Create orbit accept notification
  Future<void> createOrbitAcceptNotification({
    required String recipientId,
    required String orbitType,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .single();

      final orbitLabel = orbitType == 'inner' ? 'Inner Orbit' : 'Outer Orbit';

      await _supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': userId,
        'type': 'orbit_accept',
        'orbit_type': orbitType,
        'title': '${profile['username']} added you to their $orbitLabel',
        'body': null,
      });
    } catch (e) {
      debugPrint('Error creating orbit accept notification: $e');
    }
  }

  // Subscribe to real-time notifications
  RealtimeChannel subscribeToNotifications(Function(Map<String, dynamic>) onNotification) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            onNotification(payload.newRecord);
          },
        )
        .subscribe();
  }
}
