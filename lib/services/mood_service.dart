import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Service for managing user mood state
class MoodService {
  final _supabase = Supabase.instance.client;

  /// Available moods in the app
  static const List<String> availableMoods = [
    'Happy',
    'Sad',
    'Tired',
    'Irritated',
    'Lonely',
    'Bored',
    'Peaceful',
    'Grateful',
    'Neutral',
  ];

  /// Get emoji for a mood
  static String getMoodEmoji(String mood) {
    switch (mood) {
      case 'Happy':
        return '🤩';
      case 'Sad':
        return '😢';
      case 'Tired':
        return '😴';
      case 'Irritated':
        return '😤';
      case 'Lonely':
        return '😶‍🌫️';
      case 'Bored':
        return '😑';
      case 'Peaceful':
        return '😌';
      case 'Grateful':
        return '🙏';
      default:
        return '😐';
    }
  }

  /// Update current user's mood
  /// Returns true if successful
  Future<bool> updateMood(
    String mood, {
    bool isAutoDetected = false,
    String? sourceType,
    String? sourceId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Validate mood
      if (!availableMoods.contains(mood)) {
        debugPrint('Invalid mood: $mood');
        return false;
      }

      // Update profile with current mood
      await _supabase.from('profiles').update({
        'current_mood': mood,
        'mood_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ Mood updated successfully: $mood (auto: $isAutoDetected, source: $sourceType)');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating mood: $e');
      return false;
    }
  }

  /// Get current user's mood
  /// Returns 'Neutral' as default if not set or on error
  Future<String> getCurrentMood() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Neutral';

      final response = await _supabase
          .from('profiles')
          .select('current_mood')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return 'Neutral';
      return (response['current_mood'] as String?) ?? 'Neutral';
    } catch (e) {
      debugPrint('Error fetching current mood: $e');
      return 'Neutral';
    }
  }

  /// Get another user's mood
  /// Returns 'Neutral' as default if not set or on error
  Future<String> getUserMood(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('current_mood')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return 'Neutral';
      return (response['current_mood'] as String?) ?? 'Neutral';
    } catch (e) {
      debugPrint('Error fetching user mood: $e');
      return 'Neutral';
    }
  }

  /// Stream of mood changes for a specific user
  /// Useful for real-time updates
  Stream<String> subscribeMoodChanges(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return 'Neutral';
          final profile = data.first;
          return (profile['current_mood'] as String?) ?? 'Neutral';
        });
  }

  /// Get mood data for display
  static Map<String, dynamic> getMoodData(String mood) {
    return {
      'mood': mood,
      'emoji': getMoodEmoji(mood),
      'label': mood,
    };
  }

  /// Get all available moods with their data
  static List<Map<String, dynamic>> getAllMoodsData() {
    return availableMoods.map((mood) => getMoodData(mood)).toList();
  }
}
