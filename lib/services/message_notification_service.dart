import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class MessageNotificationService {
  final _supabase = Supabase.instance.client;

  // Create notification when message is sent
  Future<void> createMessageNotification({
    required String recipientId,
    required String messagePreview,
    String? chatId,
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
        'type': 'message',
        'title': '${profile['username']} sent you a message',
        'body': messagePreview.length > 100
            ? '${messagePreview.substring(0, 100)}...'
            : messagePreview,
      });
    } catch (e) {
      debugPrint('Error creating message notification: $e');
    }
  }

  // Create notification for comment notification
  Future<void> createCommentReplyNotification({
    required String recipientId,
    required String commentId,
    required String postId,
    required String replyPreview,
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
        'type': 'reply',
        'comment_id': commentId,
        'post_id': postId,
        'title': '${profile['username']} replied to your comment',
        'body': replyPreview.length > 100
            ? '${replyPreview.substring(0, 100)}...'
            : replyPreview,
      });
    } catch (e) {
      debugPrint('Error creating comment reply notification: $e');
    }
  }
}
