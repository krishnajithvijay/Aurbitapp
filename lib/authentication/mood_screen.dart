import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main screens/main_screen.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  // Mood Data
  final List<Map<String, dynamic>> _moods = [
    {
      'label': 'Happy',
      'emoji': '😊',
      'color': const Color(0xFFFFF9E5), // Light Yellow
      'borderColor': const Color(0xFFFFE082),
    },
    {
      'label': 'Sad',
      'emoji': '😢',
      'color': const Color(0xFFFFEBEB), // Light Pink
      'borderColor': const Color(0xFFFFCDD2),
    },
    {
      'label': 'Tired',
      'emoji': '😴',
      'color': const Color(0xFFE3F2FD), // Light Blue
      'borderColor': const Color(0xFFBBDEFB),
    },
    {
      'label': 'Irritated',
      'emoji': '😤',
      'color': const Color(0xFFFFF3E0), // Light Orange
      'borderColor': const Color(0xFFFFCC80),
    },
    {
      'label': 'Lonely',
      'emoji': '☁️',
      'color': const Color(0xFFF3F4F6), // Greyish
      'borderColor': const Color(0xFFCFD8DC),
    },
    {
      'label': 'Bored',
      'emoji': '😐',
      'color': const Color(0xFFF5F5F5), // Light Grey
      'borderColor': const Color(0xFFE0E0E0),
    },
  ];

  int? _selectedIndex;
  bool _isSaving = false;

  Future<void> _handleMoodSelection(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    // Animate and save
    await Future.delayed(const Duration(milliseconds: 300)); // Wait for animation
    
    _saveMood(index);
  }

  Future<void> _saveMood(int index) async {
    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final moodData = _moods[index];
        final moodLabel = moodData['label'] as String;

        // Insert into mood_logs table
        await Supabase.instance.client.from('mood_logs').insert({
          'user_id': user.id,
          'mood': moodLabel,
          // 'picked_at': DateTime.now().toIso8601String(), // defaulted in SQL usually, but can send
        });

        if (mounted) {
          // Navigate to Home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to your space!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving mood. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'How are you feeling?',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your current mood',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _moods.length,
                  itemBuilder: (context, index) {
                    return MoodCard(
                      mood: _moods[index],
                      isSelected: _selectedIndex == index,
                      onTap: () => _handleMoodSelection(index),
                    );
                  },
                ),
              ),

              TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class MoodCard extends StatefulWidget {
  final Map<String, dynamic> mood;
  final bool isSelected;
  final VoidCallback onTap;

  const MoodCard({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(MoodCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.mood['color'],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected ? Colors.black : widget.mood['borderColor'],
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.mood['emoji'],
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 12),
              Text(
                widget.mood['label'],
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
