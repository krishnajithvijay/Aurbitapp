import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityAdminService {
  final _supabase = Supabase.instance.client;

  // Check if current user is admin of a community
  Future<bool> isAdmin(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase
          .from('community_members')
          .select('role')
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();

      return result?['role'] == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Update community name and bio
  Future<bool> updateCommunityInfo({
    required String communityId,
    String? name,
    String? bio,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('communities')
          .update(updates)
          .eq('id', communityId);

      return true;
    } catch (e) {
      debugPrint('Error updating community info: $e');
      return false;
    }
  }

  // Get community members with details
  Future<List<Map<String, dynamic>>> getMembersWithDetails(
    String communityId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_community_members_detailed',
        params: {'p_community_id': communityId},
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching members with details: $e');
      return [];
    }
  }

  // Kick a member (force leave)
  Future<Map<String, dynamic>> kickMember({
    required String communityId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);

      return {'success': true, 'message': 'Member removed from community'};
    } catch (e) {
      debugPrint('Error kicking member: $e');
      return {'success': false, 'message': 'Failed to remove member: $e'};
    }
  }

  // Ban a member (cannot rejoin for 20 days)
  Future<Map<String, dynamic>> banMember({
    required String communityId,
    required String userId,
    String? reason,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // First, remove them from the community
      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);

      // Then, add them to the bans table
      await _supabase.from('community_bans').insert({
        'community_id': communityId,
        'user_id': userId,
        'banned_by': currentUserId,
        'reason': reason ?? 'Banned by admin',
      });

      return {'success': true, 'message': 'Member banned for 20 days'};
    } catch (e) {
      debugPrint('Error banning member: $e');
      return {'success': false, 'message': 'Failed to ban member: $e'};
    }
  }

  // Restrict a member (cannot post)
  Future<Map<String, dynamic>> restrictMember({
    required String communityId,
    required String userId,
    required bool restrict,
    String? reason,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final updates = <String, dynamic>{
        'is_restricted': restrict,
      };

      if (restrict) {
        updates['restricted_by'] = currentUserId;
        updates['restricted_at'] = DateTime.now().toIso8601String();
        updates['restriction_reason'] = reason ?? 'Restricted by admin';
      } else {
        updates['restricted_by'] = null;
        updates['restricted_at'] = null;
        updates['restriction_reason'] = null;
      }

      await _supabase
          .from('community_members')
          .update(updates)
          .eq('community_id', communityId)
          .eq('user_id', userId);

      return {
        'success': true,
        'message': restrict ? 'Member restricted' : 'Restriction removed',
      };
    } catch (e) {
      debugPrint('Error restricting member: $e');
      return {'success': false, 'message': 'Failed to update restriction: $e'};
    }
  }

  // Promote member to admin
  Future<Map<String, dynamic>> promoteMember({
    required String communityId,
    required String userId,
    required String role, // 'admin', 'moderator', or 'member'
  }) async {
    try {
      await _supabase
          .from('community_members')
          .update({'role': role})
          .eq('community_id', communityId)
          .eq('user_id', userId);

      return {
        'success': true,
        'message': 'Member role updated to $role',
      };
    } catch (e) {
      debugPrint('Error promoting member: $e');
      return {'success': false, 'message': 'Failed to update role: $e'};
    }
  }

  // Check if user is banned
  Future<Map<String, dynamic>?> checkBanStatus({
    required String communityId,
    required String userId,
  }) async {
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

  // Unban a member
  Future<Map<String, dynamic>> unbanMember({
    required String communityId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('community_bans')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);

      return {'success': true, 'message': 'Member unbanned successfully'};
    } catch (e) {
      debugPrint('Error unbanning member: $e');
      return {'success': false, 'message': 'Failed to unban member: $e'};
    }
  }

  // Get banned members list
  Future<List<Map<String, dynamic>>> getBannedMembers(
    String communityId,
  ) async {
    try {
      final response = await _supabase
          .from('community_bans')
          .select('''
            *,
            profile:user_id(id, username, avatar_url, is_verified)
          ''')
          .eq('community_id', communityId)
          .gt('ban_expires_at', DateTime.now().toIso8601String())
          .order('banned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching banned members: $e');
      return [];
    }
  }
  // Delete community
  Future<bool> deleteCommunity(String communityId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // Verify admin status first (extra safety) or trust RLS
      // Proceed to delete
      await _supabase
          .from('communities')
          .delete()
          .eq('id', communityId);
          
      return true;
    } catch (e) {
      debugPrint('Error deleting community: $e');
      return false;
    }
  }
}
