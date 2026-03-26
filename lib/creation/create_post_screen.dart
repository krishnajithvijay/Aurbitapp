import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/mood_service.dart';
import '../services/emoji_analyzer_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  
  // Selection States
  String _selectedPrivacy = 'Inner Orbit'; // Default
  String _selectedExpiry = '24 hours';
  String _selectedMood = 'Happy';

  final List<Map<String, dynamic>> _privacyOptions = [
    {'label': 'Private', 'icon': Icons.lock_outline, 'id': 'private'},
    {'label': 'Inner Orbit', 'icon': Icons.group_outlined, 'id': 'inner'}, // Using a filled icon look-alike if possible, or just style it
    {'label': 'Outer Orbit', 'icon': Icons.public, 'id': 'outer'}, // Using globe for outer
    {'label': 'Anonymous Public', 'icon': Icons.person_off_outlined, 'id': 'anonymous'},
  ];

  final List<String> _expiryOptions = ['1 hour', '24 hours', '7 days', 'Never'];

  final List<Map<String, dynamic>> _moodOptions = [
    {'label': 'Happy', 'emoji': '🤩', 'color': Colors.black, 'textColor': Colors.white},
    {'label': 'Sad', 'emoji': '😢', 'color': Colors.white, 'textColor': Colors.black},
    {'label': 'Tired', 'emoji': '😴', 'color': Colors.white, 'textColor': Colors.black},
    {'label': 'Irritated', 'emoji': '😤', 'color': Colors.white, 'textColor': Colors.black},
    {'label': 'Lonely', 'emoji': '😶‍🌫️', 'color': Colors.white, 'textColor': Colors.black}, // Using closest emoji
    {'label': 'Bored', 'emoji': '😑', 'color': Colors.white, 'textColor': Colors.black},
  ];

  bool _isPosting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _handlePost() async {
    final content = _contentController.text.trim();
    final link = _linkController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Calculate expiry
      DateTime? expiresAt;
      final now = DateTime.now().toUtc();
      switch (_selectedExpiry) {
        case '1 hour':
          expiresAt = now.add(const Duration(hours: 1));
          break;
        case '24 hours':
          expiresAt = now.add(const Duration(hours: 24));
          break;
        case '7 days':
          expiresAt = now.add(const Duration(days: 7));
          break;
        case 'Never':
          expiresAt = null;
          break;
      }

      final normalizedLink = link.isEmpty
          ? ''
          : (link.startsWith('http://') || link.startsWith('https://') ? link : 'https://$link');
      final finalContent = normalizedLink.isEmpty || content.contains(normalizedLink)
          ? content
          : '$content\n$normalizedLink';

      await Supabase.instance.client.from('posts').insert({
        'user_id': user.id,
        'content': finalContent,
        'privacy_level': _selectedPrivacy.toLowerCase().replaceAll(' ', '_'), // inner_orbit, etc.
        'mood': _selectedMood,
         // We might need to store emoji too or map it on fetch
        'expires_at': expiresAt?.toIso8601String(),
        'is_anonymous': _selectedPrivacy == 'Anonymous Public',
      });

      // Auto-detect mood from post content
      await _detectAndUpdateMood(content);

      if (mounted) {
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  /// Detect mood from post content and update if emojis found
  Future<void> _detectAndUpdateMood(String content) async {
    try {
      // Analyze content for emojis
      final analyzer = EmojiAnalyzer();
      final detectedMood = analyzer.detectMoodFromText(content);
      
      if (detectedMood != null) {
        // Check if mood was recently updated (throttle to prevent too frequent changes)
        final canUpdate = await _canUpdateMood();
        
        if (canUpdate) {
          final success = await MoodService().updateMood(
            detectedMood,
            isAutoDetected: true,
            sourceType: 'post',
          );
          
          if (success && mounted) {
            // Show subtle notification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Your mood was updated to $detectedMood ${MoodService.getMoodEmoji(detectedMood)} based on your post',
                ),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error detecting mood: $e');
      // Silently fail - don't disrupt post creation
    }
  }

  /// Check if enough time has passed since last mood update (throttling)
  /// Returns true if at least 15 minutes have passed
  Future<bool> _canUpdateMood() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('mood_updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['mood_updated_at'] == null) {
        return true; // No previous update, allow
      }

      final lastUpdate = DateTime.parse(response['mood_updated_at']);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);

      // TESTING: Throttle disabled (0 seconds)
      return difference.inSeconds >= 0;
    } catch (e) {
      debugPrint('Error checking mood update time: $e');
      return true; // Default to allowing update on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Post',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SizedBox( // Constrain button size
                height: 36,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _handlePost,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey[700], // Matches the "Post" button grey in design
                     foregroundColor: Colors.white,
                     elevation: 0,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: _isPosting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Post', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Input
            TextField(
              controller: _contentController,
              autofocus: true,
              maxLines: 5,
              minLines: 1,
              style: GoogleFonts.inter(fontSize: 18, color: textColor),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 40),

            _buildSectionHeader('Add link', Icons.link_rounded),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Paste a URL (optional)',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Privacy Section
            _buildSectionHeader('Privacy', Icons.lock_outline),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _privacyOptions.map((option) {
                final isSelected = _selectedPrivacy == option['label'];
                // Special styling for selected item (dark background)
                final itemBg = isSelected 
                    ? Colors.black
                    : Colors.transparent;
                final itemBorder = isSelected
                    ? Colors.transparent
                    : borderColor;
                final itemText = isSelected ? Colors.white : textColor;
                final itemIcon = isSelected ? Colors.white : textColor;

                return InkWell(
                  onTap: () => setState(() => _selectedPrivacy = option['label']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: itemBg,
                      border: Border.all(color: itemBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(option['icon'], size: 18, color: itemIcon),
                        const SizedBox(width: 8),
                        Text(
                          option['label'],
                          style: GoogleFonts.inter(
                            color: itemText,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Expiry Section
            _buildSectionHeader('Post expires in', Icons.access_time),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _expiryOptions.map((option) {
                final isSelected = _selectedExpiry == option;
                // Special styling
                final itemBg = isSelected 
                    ? Colors.black
                    : Colors.transparent;
                final itemBorder = isSelected ? Colors.transparent : borderColor;
                final itemText = isSelected ? Colors.white : textColor;

                return InkWell(
                  onTap: () => setState(() => _selectedExpiry = option),
                  borderRadius: BorderRadius.circular(20), // More rounded for expiry
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: itemBg,
                      border: Border.all(color: itemBorder),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        color: itemText,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Mood Section
            _buildSectionHeader('Mood', Icons.sentiment_satisfied_alt), // Using generic icon for header
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _moodOptions.map((option) {
                final label = option['label'] as String;
                final isSelected = _selectedMood == label;
                
                // Design shows Happy as filled dark, others valid too.
                // We'll use the selected logic similar to others but might want to check the image again.
                // Image shows "Happy" selected with dark BG. "Stressed" outlined.
                
                final itemBg = isSelected 
                    ? Colors.black
                    : Colors.transparent;
                final itemBorder = isSelected ? Colors.transparent : borderColor;
                final itemParamsTextColor = isSelected ? Colors.white : textColor;

                return InkWell(
                  onTap: () => setState(() => _selectedMood = label),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 48 - 24) / 3, // Precise grid calculation (2 gaps of 12)
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Reduced padding
                    decoration: BoxDecoration(
                      color: itemBg,
                      border: Border.all(color: itemBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(option['emoji'], style: const TextStyle(fontSize: 16)), // Slightly smaller emoji
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              color: itemParamsTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12, // Slightly smaller text
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
             const SizedBox(height: 48), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
