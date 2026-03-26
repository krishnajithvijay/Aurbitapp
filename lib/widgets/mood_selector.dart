import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mood_service.dart';

/// Bottom sheet widget for selecting user mood
class MoodSelector extends StatelessWidget {
  final String currentMood;
  final Function(String) onMoodSelected;

  const MoodSelector({
    super.key,
    required this.currentMood,
    required this.onMoodSelected,
  });

  /// Show mood selector as bottom sheet
  static Future<String?> show(BuildContext context, String currentMood) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoodSelector(
        currentMood: currentMood,
        onMoodSelected: (mood) {
          Navigator.pop(context, mood);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Text(
                'How are you feeling?',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your current mood',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 24),

              // Mood grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: MoodService.availableMoods.length,
                itemBuilder: (context, index) {
                  final mood = MoodService.availableMoods[index];
                  final emoji = MoodService.getMoodEmoji(mood);
                  final isSelected = mood == currentMood;

                  return _MoodOption(
                    mood: mood,
                    emoji: emoji,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      // Haptic feedback
                      onMoodSelected(mood);
                    },
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodOption extends StatelessWidget {
  final String mood;
  final String emoji;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodOption({
    required this.mood,
    required this.emoji,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? (isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50])
        : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]);

    final borderColor = isSelected
        ? (isDark ? Colors.blue[400] : Colors.blue[300])
        : (isDark ? Colors.grey[800] : Colors.grey[200]);

    final textColor = isSelected
        ? (isDark ? Colors.blue[200] : Colors.blue[700])
        : (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              mood,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
