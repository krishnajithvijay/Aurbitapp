// EXAMPLE INTEGRATION FILE
// This file shows how to integrate all the new admin features and verification
// into your existing community feed screen. Copy relevant parts to your actual screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/community_admin_service.dart';
import '../services/community_service.dart';
import '../widgets/verified_badge.dart';
import '../widgets/admin_only.dart';
import '../widgets/ban_warning_dialog.dart';
import 'community_members_screen.dart';
import 'community_settings_screen.dart';

class ExampleCommunityFeedIntegration extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String? communityBio;

  const ExampleCommunityFeedIntegration({
    super.key,
    required this.communityId,
    required this.communityName,
    this.communityBio,
  });

  @override
  State<ExampleCommunityFeedIntegration> createState() =>
      _ExampleCommunityFeedIntegrationState();
}

class _ExampleCommunityFeedIntegrationState
    extends State<ExampleCommunityFeedIntegration> {
  final _communityService = CommunityService();
  final _adminService = CommunityAdminService();
  bool _isMember = false;
  bool _isLoading = true;
  String _communityName = '';
  String _communityBio = '';

  @override
  void initState() {
    super.initState();
    _communityName = widget.communityName;
    _communityBio = widget.communityBio ?? '';
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    setState(() => _isLoading = true);
    final isMember = await _communityService.isMember(widget.communityId);
    setState(() {
      _isMember = isMember;
      _isLoading = false;
    });
  }

  Future<void> _handleJoinCommunity() async {
    final result = await _communityService.joinCommunity(widget.communityId);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        _checkMembership();
      } else if (result['banned'] == true) {
        // Show ban warning dialog
        await BanWarningDialog.show(
          context: context,
          daysRemaining: result['banInfo']['days_remaining'],
          reason: result['banInfo']['reason'],
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLeaveCommunity() async {
    final confirmed = await CommunityService.showLeaveCommunityDialog(
      context,
      _communityName,
    );

    if (confirmed) {
      final success = await _communityService.leaveCommunity(widget.communityId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left community successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _checkMembership();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to leave community'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunitySettingsScreen(
          communityId: widget.communityId,
          currentName: _communityName,
          currentBio: _communityBio,
        ),
      ),
    );

    // If changes were made, refresh community info
    if (result == true) {
      // TODO: Reload community data from database
      // For now, just show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Community updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _navigateToMembers() async {
    final isAdmin = await _adminService.isAdmin(widget.communityId);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommunityMembersScreen(
            communityId: widget.communityId,
            communityName: _communityName,
            isAdmin: isAdmin,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          _communityName,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        elevation: 0,
        actions: [
          // Members button (always visible to members)
          if (_isMember)
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: _navigateToMembers,
              tooltip: 'View Members',
            ),
          
          // Settings button (only visible to admins)
          AdminOnly(
            communityId: widget.communityId,
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _navigateToSettings,
              tooltip: 'Community Settings',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Community header with bio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_communityBio.isNotEmpty) ...[
                  Text(
                    _communityBio,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Join/Leave button
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isMember ? _handleLeaveCommunity : _handleJoinCommunity,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isMember ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isMember ? 'Leave Community' : 'Join Community',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Posts feed
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // TODO: Replace with actual posts
                _buildExamplePost(
                  username: 'john_doe',
                  isVerified: true, // This should come from the database
                  content: 'This is an example post with a verified badge!',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildExamplePost(
                  username: 'jane_smith',
                  isVerified: false,
                  content: 'This user is not verified.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamplePost({
    required String username,
    required bool isVerified,
    required String content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author with verification badge
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: Text(
                  username[0].toUpperCase(),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Use the UsernameWithBadge widget
              UsernameWithBadge(
                username: username,
                isVerified: isVerified,
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
                badgeSize: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/*
 * INTEGRATION CHECKLIST:
 * 
 * 1. Import required files:
 *    - community_admin_service.dart
 *    - community_service.dart (updated version)
 *    - verified_badge.dart
 *    - admin_only.dart
 *    - ban_warning_dialog.dart
 *    - community_members_screen.dart
 *    - community_settings_screen.dart
 * 
 * 2. Update join/leave logic to use new return format
 * 
 * 3. Add verification badges to all username displays:
 *    - Use UsernameWithBadge widget
 *    - Ensure is_verified is fetched from database
 * 
 * 4. Add members and settings buttons to app bar:
 *    - Members button for all members
 *    - Settings button wrapped in AdminOnly widget
 * 
 * 5. Display community bio if available
 * 
 * 6. Update database queries to include is_verified:
 *    SELECT *, profile:user_id(id, username, avatar_url, is_verified)
 * 
 * 7. Test all features:
 *    - Join/leave with ban checking
 *    - View members
 *    - Admin settings (if admin)
 *    - Verification badges display
 */
