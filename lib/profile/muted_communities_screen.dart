import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MutedCommunitiesScreen extends StatefulWidget {
  const MutedCommunitiesScreen({super.key});

  @override
  State<MutedCommunitiesScreen> createState() => _MutedCommunitiesScreenState();
}

class _MutedCommunitiesScreenState extends State<MutedCommunitiesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _mutedCommunities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMutedCommunities();
  }

  Future<void> _fetchMutedCommunities() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('muted_communities')
          .select('id, created_at, communities(id, name, description)') // Adjust columns based on schema
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _mutedCommunities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching muted communities: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unmuteCommunity(String muteId, String name) async {
    try {
      await _supabase.from('muted_communities').delete().eq('id', muteId);
      
      setState(() {
        _mutedCommunities.removeWhere((item) => item['id'] == muteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unmuted $name')),
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
          'Muted Communities',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mutedCommunities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_2_outlined, size: 60, color: secondaryText),
                      const SizedBox(height: 16),
                      Text(
                        'No muted communities',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Communities you mute will appear here',
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
                  itemCount: _mutedCommunities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _mutedCommunities[index];
                    final community = item['communities'] as Map<String, dynamic>;
                    final muteId = item['id'];
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tileColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      ),
                      leading: Container(
                        width: 40, 
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.groups, color: isDark ? Colors.white : Colors.black),
                      ),
                      title: Text(
                        community['name'] ?? 'Community',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        community['description'] ?? '',
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                         style: GoogleFonts.inter(fontSize: 12, color: secondaryText),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unmuteCommunity(muteId, community['name'] ?? 'Community'),
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
}
