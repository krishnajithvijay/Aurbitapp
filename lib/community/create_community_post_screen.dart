import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/mood_service.dart';
import '../services/emoji_analyzer_service.dart';

class CreateCommunityPostScreen extends StatefulWidget {
  final Map<String, dynamic> community;

  const CreateCommunityPostScreen({
    super.key,
    required this.community,
  });

  @override
  State<CreateCommunityPostScreen> createState() => _CreateCommunityPostScreenState();
}

class _CreateCommunityPostScreenState extends State<CreateCommunityPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  String? _selectedMood;
  bool _isAnonymous = false;
  bool _isPosting = false;

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Happy', 'emoji': '🤩'},
    {'name': 'Sad', 'emoji': '😢'},
    {'name': 'Tired', 'emoji': '😴'},
    {'name': 'Irritated', 'emoji': '😤'},
    {'name': 'Lonely', 'emoji': '😶‍🌫️'},
    {'name': 'Bored', 'emoji': '😑'},
    {'name': 'Peaceful', 'emoji': '😌'},
    {'name': 'Grateful', 'emoji': '🙏'},
  ];

  @override
  void dispose() {
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    final link = _linkController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something to post')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is a member
      final membership = await _supabase
          .from('community_members')
          .select()
          .eq('community_id', widget.community['id'])
          .eq('user_id', userId)
          .maybeSingle();

      if (membership == null) {
        throw Exception('You must be a member to post in this community');
      }

      final normalizedLink = link.isEmpty
          ? ''
          : (link.startsWith('http://') || link.startsWith('https://') ? link : 'https://$link');
      final finalContent = normalizedLink.isEmpty || content.contains(normalizedLink)
          ? content
          : '$content\n$normalizedLink';

      // Create the post
      await _supabase.from('community_posts').insert({
        'community_id': widget.community['id'],
        'user_id': userId,
        'content': finalContent,
        'mood': _selectedMood,
        'is_anonymous': _isAnonymous,
      });

      // Auto-detect mood from post content
      await _detectAndUpdateMood(content);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  /// Detect mood from post content and update if emojis found
  Future<void> _detectAndUpdateMood(String content) async {
    try {
      final analyzer = EmojiAnalyzer();
      final detectedMood = analyzer.detectMoodFromText(content);
      
      if (detectedMood != null) {
        final canUpdate = await _canUpdateMood();
        
        if (canUpdate) {
          final success = await MoodService().updateMood(
            detectedMood,
            isAutoDetected: true,
            sourceType: 'community_post',
          );
          
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Mood updated to $detectedMood ${MoodService.getMoodEmoji(detectedMood)}',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error detecting mood: $e');
    }
  }

  Future<bool> _canUpdateMood() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('mood_updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['mood_updated_at'] == null) {
        return true;
      }

      final lastUpdate = DateTime.parse(response['mood_updated_at']);
      final difference = DateTime.now().difference(lastUpdate);
      return difference.inSeconds >= 0; // TESTING: Throttle disabled
    } catch (e) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Post',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _createPost,
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Post',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Community Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.community['name'] ?? 'Community',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Posting to community',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Content Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: 8,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: textColor,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts with the community...',
                  hintStyle: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Add link (optional)',
                  hintStyle: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.link_rounded, color: secondaryTextColor, size: 18),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mood Selection
            Text(
              'How are you feeling?',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = isSelected ? null : mood['name'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.blue[900] : Colors.blue[50])
                          : (isDark ? Colors.grey[800] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? Border.all(
                              color: isDark ? Colors.blue[700]! : Colors.blue[300]!,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mood['emoji'],
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mood['name'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.blue[200] : Colors.blue[700])
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Anonymous Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post Anonymously',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Your name won\'t be shown',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAnonymous,
                    onChanged: (value) {
                      setState(() => _isAnonymous = value);
                    },
                    activeColor: isDark ? Colors.blue[400] : Colors.blue[600],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Guidelines
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue[900]!.withOpacity(0.2)
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.blue[800]! : Colors.blue[100]!,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Be respectful and supportive. This is a safe space for everyone.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.blue[200] : Colors.blue[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
