import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../web/aurbit_web_theme.dart'; // Import AurbitWebTheme

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isCreating = false;

  static final RegExp _communityHandleRegex = RegExp(r'^[a-z0-9_]{3,25}$');

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    final usernameHandle = _usernameController.text.trim().toLowerCase();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a community name')),
      );
      return;
    }

    if (!_communityHandleRegex.hasMatch(usernameHandle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be 3-25 chars: lowercase letters, numbers, underscore')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Get username from profile
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      
      final username = profile['username'] ?? 'User';

      // Pre-check uniqueness for better UX before insert
      final existing = await Supabase.instance.client
          .from('communities')
          .select('id')
          .eq('username', usernameHandle)
          .maybeSingle();

      if (existing != null) {
        throw Exception('That community username is already taken');
      }

      // Create the community
      final communityResponse = await Supabase.instance.client
          .from('communities')
          .insert({
        'name': name,
        'username': usernameHandle,
        'description': desc.isEmpty ? null : desc,
        'bio': desc.isEmpty ? null : desc,
        'mood': 'General', // Default mood
        'created_by': user.id,
        'created_by_username': username,
        'members_count': 1, // keep optimistic; DB trigger can overwrite with exact count
        'active_count': 0,
        'status': 'active',
      }).select().single();

      final communityId = communityResponse['id'];

      // Automatically add creator as admin member
      await Supabase.instance.client.from('community_members').upsert({
        'community_id': communityId,
        'user_id': user.id,
        'username': username.toString().trim().isEmpty ? 'User' : username,
        'role': 'admin', // Creator is automatically an admin
      }, onConflict: 'community_id,user_id');

      if (mounted) {
        Navigator.pop(context, true); // Return success signal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating community: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    var bgColor = isDark ? Colors.black : Colors.white;
    var textColor = isDark ? Colors.white : Colors.black;
    var borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    var inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; 

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Community',
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
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey[600],
                     foregroundColor: Colors.white,
                     elevation: 0,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: _isCreating 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
          children: [
            // Avatar Placeholder
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFE5E7EB), // Light gray
                  borderRadius: BorderRadius.circular(24), // Squircle
                ),
                child: Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 48,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Community Name
            _buildLabel('Community Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: 'e.g., Mindful Moments',
              maxLength: 50,
              maxLines: 1,
              isDark: isDark,
              borderColor: borderColor,
            ),
            
            const SizedBox(height: 24),

            // Community Username
            _buildLabel('Community Username (c/handle)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _usernameController,
              hint: 'e.g., mindfulness',
              maxLength: 25,
              maxLines: 1,
              isDark: isDark,
              borderColor: borderColor,
              prefixText: 'c/',
            ),
            
            const SizedBox(height: 24),

            // Description
            _buildLabel('Description'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descController,
              hint: 'Describe what your community is about...',
              maxLength: 200,
              maxLines: 4,
              isDark: isDark,
              borderColor: borderColor,
            ),

            const SizedBox(height: 32),

            // Guidelines Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6), // Very light gray blue
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Guidelines',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGuidelineText('• Be respectful and supportive to all members', textColor),
                  _buildGuidelineText('• Keep posts relevant to the community\'s mood and topic', textColor),
                  _buildGuidelineText('• No spam or self-promotion', textColor),
                  _buildGuidelineText('• Protect everyone\'s privacy and anonymity', textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required int maxLines,
    required bool isDark,
    required Color borderColor,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              prefixText: prefixText,
              prefixStyle: GoogleFonts.inter(
                color: AurbitWebTheme.accentPrimary,
                fontWeight: FontWeight.bold,
              ),
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              counterText: "", // Hide default counter
            ),
            maxLength: maxLength,
            onChanged: (val) => setState(() {}),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${controller.text.length}/$maxLength',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildGuidelineText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: color.withOpacity(0.7),
          height: 1.4,
        ),
      ),
    );
  }
}
