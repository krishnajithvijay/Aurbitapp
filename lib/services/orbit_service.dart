import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_orbit.dart';
import '../models/mood_log.dart';


import '../services/notification_service.dart';

class OrbitService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  /// Send an orbit request to a user (instead of adding directly)
  Future<void> sendOrbitRequest(String friendId, String orbitType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    // Ensure valid orbit type
    final type = OrbitType.fromString(orbitType).value;

    // Create notification for the recipient
    await _notificationService.createOrbitRequestNotification(
      recipientId: friendId,
      orbitType: type,
    );
  }

  /// Accept an orbit request: adds sender to my orbit, and me to sender's orbit
  Future<void> acceptOrbitRequest({
    required String senderId,          // The person who sent the request
    required String myOrbitForSender,  // Who I want to put them as (Inner/Outer)
    required String senderOrbitForMe,  // Who they wanted to put me as (from notification)
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Use RPC to bypass RLS for the reciprocal insert
    await _supabase.rpc('accept_orbit_request', params: {
      'p_friend_id': senderId,
      'p_my_orbit_type': OrbitType.fromString(myOrbitForSender).value,
      'p_their_orbit_type': OrbitType.fromString(senderOrbitForMe).value,
    });
  }

  /// Add a user to the orbit (Direct add - used internally or if no request flow needed)
  Future<void> addToOrbit(String friendId, String orbitType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    // Ensure valid orbit type
    final type = OrbitType.fromString(orbitType).value;

    await _supabase.from('user_orbits').insert({
       'user_id': user.id,
       'friend_id': friendId,
       'orbit_type': type,
    });
  }

  /// Remove a user from the orbit
  Future<void> removeFromOrbit(String friendId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase
        .from('user_orbits')
        .delete()
        .eq('user_id', user.id)
        .eq('friend_id', friendId);
  }

  /// Update the orbit type (inner <-> outer)
  Future<void> updateOrbitType(String friendId, String orbitType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Ensure valid orbit type
    final type = OrbitType.fromString(orbitType).value;

    await _supabase
        .from('user_orbits')
        .update({'orbit_type': type})
        .eq('user_id', user.id)
        .eq('friend_id', friendId);
  }

  /// Get the user's entire orbit with profile details
  Future<List<UserOrbit>> getMyOrbit() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await _supabase
        .from('user_orbits')
        .select('*, profiles:friend_id(username, avatar_url, is_verified, current_mood)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List).map((e) => UserOrbit.fromJson(e)).toList();
  }

  /// Get orbit members by type (inner/outer)
  Future<List<UserOrbit>> getOrbitByType(String orbitType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    final type = OrbitType.fromString(orbitType).value;

    final response = await _supabase
        .from('user_orbits')
        .select('*, profiles:friend_id(username, avatar_url, is_verified, current_mood)')
        .eq('user_id', user.id)
        .eq('orbit_type', type)
        .order('created_at', ascending: false);

    return (response as List).map((e) => UserOrbit.fromJson(e)).toList();
  }

  /// Check if a user is already in the orbit
  Future<bool> isInOrbit(String friendId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final response = await _supabase
        .from('user_orbits')
        .select('id')
        .eq('user_id', user.id)
        .eq('friend_id', friendId)
        .maybeSingle();

    return response != null;
  }
  
  /// Get the specific orbit type for a friend, returns null if not in orbit
  Future<String?> getOrbitType(String friendId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('user_orbits')
        .select('orbit_type')
        .eq('user_id', user.id)
        .eq('friend_id', friendId)
        .maybeSingle();

    return response != null ? response['orbit_type'] as String : null;
  }

  /// Check if there is a pending orbit request sent to this user
  Future<bool> hasPendingOrbitRequest(String friendId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('sender_id', user.id)
          .eq('recipient_id', friendId)
          .eq('type', 'orbit_request')
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      // If RLS prevents reading sent notifications, this might fail or return null.
      // Assuming RLS allows reading rows where sender_id = auth.uid()
      return false;
    }
  }

  /// Get mood history for a user
  Future<List<MoodLog>> getUserMoodHistory(String userId, {int limit = 30}) async {
    final response = await _supabase
        .from('mood_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((e) => MoodLog.fromJson(e)).toList();
  }
}
