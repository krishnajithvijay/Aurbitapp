import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MutedUsersScreen extends StatefulWidget {
  const MutedUsersScreen({super.key});

  @override
  State<MutedUsersScreen> createState() => _MutedUsersScreenState();
}

class _MutedUsersScreenState extends State<MutedUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _mutedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMutedUsers();
  }

  Future<void> _fetchMutedUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Join muted_users with profiles
      // Since supabase-flutter filter syntax with foreign tables can be tricky, 
      // we'll select muted_users columns and joined profile columns.
      final response = await _supabase
          .from('muted_users')
          .select('id, created_at, profiles:muted_user_id(id, username, avatar_url, is_verified)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _mutedUsers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching muted users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unmuteUser(String muteId, String username) async {
    try {
      await _supabase.from('muted_users').delete().eq('id', muteId);
      
      setState(() {
        _mutedUsers.removeWhere((item) => item['id'] == muteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unmuted $username')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Muted Users',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mutedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined, size: 60, color: secondaryText),
                      const SizedBox(height: 16),
                      Text(
                        'No muted users',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Users you mute will appear here',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mutedUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _mutedUsers[index];
                    final profile = item['profiles'] as Map<String, dynamic>;
                    final muteId = item['id'];
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      // Card-style background
                      tileColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      ),
                      leading: _buildAvatar(profile['avatar_url'], 40),
                      title: Text(
                        profile['username'] ?? 'User',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unmuteUser(muteId, profile['username'] ?? 'User'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: Text(
                          'Unmute',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildAvatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url != null
            ? (url.contains('.svg') || url.contains('dicebear'))
                ? SvgPicture.network(url, fit: BoxFit.cover)
                : Image.network(url, fit: BoxFit.cover)
            : Icon(Icons.person, color: Colors.white, size: size * 0.6),
      ),
    );
  }
}
