import 'package:flutter/material.dart';

/// Service for analyzing emojis in text and detecting mood
class EmojiAnalyzer {
  /// Emoji to mood mapping
  static const Map<String, List<String>> emojiToMood = {
    'Happy': [
      '😊', '😄', '😃', '😁', '🙂', '😀', '🤩', '😍', '🥰', 
      '😇', '🎉', '🎊', '💖', '❤️', '✨', '🌟', '⭐', '💕',
      '😻', '😺', '🥳', '🙌', '👏', '💪', '✌️', '🤗',
      '😂', '🤣', '😆', '😅', '😸', '😹' // Added laughing emojis
    ],
    'Sad': [
      '😢', '😭', '😞', '😔', '🥺', '💔', '😿', '😪', '😥',
      '☹️', '🙁', '😣', '😖', '😰', '😨', '😱', '😓', '😩',
      '🥲', '🥹', '🙂' // Added: smiling with tear, holding back tears, slight smile (can be sad in context)
    ],
    'Lonely': [
      '😶', '😐', '😑', '🌫️', '☁️', '🙁', '😕', '😟', '🥀',
      '🍂', '🌧️', '💭'
    ],
    'Irritated': [
      '😤', '😠', '💢', '😡', '🤬', '🤯', '🔥', '💥', '⚡'
    ],
    'Tired': [
      '😴', '🥱', '😪', '💤', '🛌', '😵', '🥴', '😑'
    ],
    'Peaceful': [
      '😌', '🧘', '☮️', '🕊️', '🌸', '🌺', '🌼', '🦋', 
      '🌈', '☀️', '🌅', '🌄'
    ],
    'Grateful': [
      '🙏', '🤲', '💝', '🎁', '😊', '🥹', '💐', '🌻'
    ],
    'Bored': [
      '😑', '😐', '🥱', '😒', '🙄'
    ],
  };

  /// Analyze text and detect dominant mood from emojis
  /// Returns null if no clear mood detected
  String? detectMoodFromText(String text) {
    if (text.trim().isEmpty) return null;

    // Extract emojis
    final emojis = extractEmojis(text);
    if (emojis.isEmpty) return null;

    // Get mood scores
    final scores = getMoodScores(emojis);
    if (scores.isEmpty) return null;

    // Get dominant mood (highest score)
    return getDominantMood(scores);
  }

  /// Extract all emojis from text
  List<String> extractEmojis(String text) {
    final emojis = <String>[];
    
    // Simple emoji extraction using Unicode ranges
    // This covers most common emojis
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|'
      r'[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|'
      r'[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{1F780}-\u{1F7FF}]|'
      r'[\u{1F800}-\u{1F8FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{2300}-\u{23FF}]|'
      r'[\u{203C}\u{2049}\u{20E3}\u{2139}\u{2194}-\u{2199}\u{21A9}-\u{21AA}]|'
      r'[\u{231A}-\u{231B}\u{2328}\u{23CF}\u{23E9}-\u{23F3}\u{23F8}-\u{23FA}]',
      unicode: true,
    );

    final matches = emojiRegex.allMatches(text);
    for (final match in matches) {
      final emoji = text.substring(match.start, match.end);
      emojis.add(emoji);
    }

    return emojis;
  }

  /// Calculate mood scores from list of emojis
  Map<String, int> getMoodScores(List<String> emojis) {
    final scores = <String, int>{};

    for (final emoji in emojis) {
      for (final entry in emojiToMood.entries) {
        final mood = entry.key;
        final moodEmojis = entry.value;

        if (moodEmojis.contains(emoji)) {
          scores[mood] = (scores[mood] ?? 0) + 1;
        }
      }
    }

    return scores;
  }

  /// Get dominant mood from scores
  /// Returns null if no clear winner or tie
  String? getDominantMood(Map<String, int> scores) {
    if (scores.isEmpty) return null;

    // Find highest score
    int maxScore = 0;
    String? dominantMood;
    int tieCount = 0;

    scores.forEach((mood, score) {
      if (score > maxScore) {
        maxScore = score;
        dominantMood = mood;
        tieCount = 1;
      } else if (score == maxScore) {
        tieCount++;
      }
    });

    // Only return if we have a clear winner (no tie)
    // and at least 2 emojis to be more confident
    if (tieCount == 1 && maxScore >= 2) {
      return dominantMood;
    }

    // If only 1 emoji but very clear mood
    if (maxScore == 1 && scores.length == 1) {
      return dominantMood;
    }

    return null;
  }

  /// Check if text contains enough emojis to analyze
  bool hasSignificantEmojis(String text) {
    final emojis = extractEmojis(text);
    return emojis.length >= 1;
  }

  /// Get mood analysis summary for debugging
  Map<String, dynamic> analyzeMoodDetails(String text) {
    final emojis = extractEmojis(text);
    final scores = getMoodScores(emojis);
    final dominantMood = getDominantMood(scores);

    return {
      'emojis': emojis,
      'emoji_count': emojis.length,
      'scores': scores,
      'dominant_mood': dominantMood,
    };
  }
}
