import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityService {
  final _supabase = Supabase.instance.client;

  // Join a community
  Future<Map<String, dynamic>> joinCommunity(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Check if user is banned
      final banStatus = await checkBanStatus(communityId, userId);
      if (banStatus != null && banStatus['is_banned'] == true) {
        final daysRemaining = banStatus['days_remaining'] ?? 0;
        return {
          'success': false,
          'banned': true,
          'message': 'You are banned from this community for $daysRemaining more days',
          'banInfo': banStatus,
        };
      }

      // Get user's username
      final profile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .single();

      await _supabase.from('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
        'username': profile['username'],
        'role': 'member',
      });

      return {'success': true, 'message': 'Successfully joined community'};
    } catch (e) {
      debugPrint('Error joining community: $e');
      return {'success': false, 'message': 'Failed to join: $e'};
    }
  }

  // Check if user is banned from a community
  Future<Map<String, dynamic>?> checkBanStatus(String communityId, String userId) async {
    try {
      final response = await _supabase.rpc(
        'is_user_banned',
        params: {
          'p_community_id': communityId,
          'p_user_id': userId,
        },
      );

      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking ban status: $e');
      return null;
    }
  }

  // Leave a community
  Future<bool> leaveCommunity(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error leaving community: $e');
      return false;
    }
  }

  // Check if user is a member
  Future<bool> isMember(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('Error checking membership: $e');
      return false;
    }
  }

  // Get community members
  Future<List<Map<String, dynamic>>> getCommunityMembers(String communityId) async {
    try {
      final response = await _supabase
          .from('community_members')
          .select('''
            *,
            profile:user_id(id, username, avatar_url)
          ''')
          .eq('community_id', communityId)
          .order('joined_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching members: $e');
      return [];
    }
  }

  // Get community posts
  Future<List<Map<String, dynamic>>> getCommunityPosts(String communityId) async {
    try {
      final response = await _supabase
          .from('community_posts')
          .select('''
            *,
            profile:user_id(id, username, avatar_url)
          ''')
          .eq('community_id', communityId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      return [];
    }
  }

  // Mute a community
  Future<void> muteCommunity(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('muted_communities').upsert({
        'user_id': userId,
        'community_id': communityId,
        // created_at is default now() in SQL, but good to be safe if client time matters or for consistency, but SQL default is fine.
      });
    } catch (e) {
      debugPrint('Error muting community: $e');
    }
  }

  // Unmute a community
  Future<void> unmuteCommunity(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('muted_communities')
          .delete()
          .eq('user_id', userId)
          .eq('community_id', communityId);
    } catch (e) {
      debugPrint('Error unmuting community: $e');
    }
  }

  // Check if community is muted
  Future<bool> isCommunityMuted(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase
          .from('muted_communities')
          .select()
          .eq('user_id', userId)
          .eq('community_id', communityId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('Error checking community mute status: $e');
      return false;
    }
  }

  // Show leave community warning dialog
  static Future<bool> showLeaveCommunityDialog(
    BuildContext context,
    String communityName,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Leave Community?',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to leave "$communityName"?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red[900]!.withOpacity(0.2)
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.red[800]! : Colors.red[100]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You will:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.red[200] : Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWarningItem(
                    '• Lose access to community posts',
                    isDark,
                  ),
                  _buildWarningItem(
                    '• No longer receive community updates',
                    isDark,
                  ),
                  _buildWarningItem(
                    '• Need to rejoin to post again',
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Leave Community',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static Widget _buildWarningItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.red[300] : Colors.red[700],
          height: 1.4,
        ),
      ),
    );
  }
}
