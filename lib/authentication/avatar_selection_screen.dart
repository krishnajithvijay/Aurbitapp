import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'mood_screen.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  String _selectedCategory = 'Indian Style';
  int? _selectedIndex;
  List<String> _avatarSeeds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateAvatars();
  }

  void _generateAvatars() {
    final random = Random();
    setState(() {
      _avatarSeeds = List.generate(8, (_) => random.nextInt(100000).toString());
      _selectedIndex = null;
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedIndex == null) return;

    setState(() => _isLoading = true);

    try {
      final seed = _avatarSeeds[_selectedIndex!];
      final avatarUrl = 'https://api.dicebear.com/9.x/adventurer/svg?seed=$seed';

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'avatar_url': avatarUrl})
            .eq('id', userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Avatar saved!')),
        );
        // Navigate to Mood Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MoodScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving avatar')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
    final borderColor = isDark ? (Colors.grey[700] ?? Colors.grey) : (Colors.grey[300] ?? Colors.grey);
    final cardBgColor = isDark ? const Color(0xFF1C1C1C) : (Colors.grey[100] ?? Colors.grey.shade100);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Title
              Text(
                'Choose your Avatar',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick an avatar that represents you',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab('Indian Style', isDark, textColor, secondaryTextColor),
                  const SizedBox(width: 32),
                  _buildTab('Western Style', isDark, textColor, secondaryTextColor),
                ],
              ),

              const SizedBox(height: 32),

              // Avatar Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: _avatarSeeds.length,
                  itemBuilder: (context, index) {
                    final seed = _avatarSeeds[index];
                    final isSelected = _selectedIndex == index;
                    final url = 'https://api.dicebear.com/9.x/adventurer/svg?seed=$seed&backgroundColor=b6e3f4,c0aede,d1d4f9';
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SvgPicture.network(
                            url,
                            fit: BoxFit.cover,
                            placeholderBuilder: (BuildContext context) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Shuffle Button
              OutlinedButton.icon(
                onPressed: _generateAvatars,
                icon: Icon(Icons.refresh, color: textColor),
                label: Text(
                  'Show me different avatars',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Continue Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedIndex == null || _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.grey[700],
                    disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: isDark ? Colors.black : Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildTab(String title, bool isDark, Color textColor, Color secondaryTextColor) {
    final isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = title;
          _generateAvatars(); // Regenerate on category switch
        });
      },
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? textColor : secondaryTextColor,
        ),
      ),
    );
  }
}
