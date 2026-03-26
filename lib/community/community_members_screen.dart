import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/community_admin_service.dart';

class CommunityMembersScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final bool isAdmin;

  const CommunityMembersScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.isAdmin,
  });

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  final _adminService = CommunityAdminService();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await _adminService.getMembersWithDetails(widget.communityId);
    setState(() {
      _members = members;
      _isLoading = false;
    });
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRestricted = member['is_restricted'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.admin_panel_settings,
              title: 'Promote to Admin',
              iconColor: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _promoteMember(member, 'admin');
              },
            ),
            _buildOptionTile(
              icon: isRestricted ? Icons.check_circle : Icons.block,
              title: isRestricted ? 'Remove Restriction' : 'Restrict Posting',
              iconColor: isRestricted ? Colors.green : Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _restrictMember(member, !isRestricted);
              },
            ),
            _buildOptionTile(
              icon: Icons.person_remove,
              title: 'Kick from Community',
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _kickMember(member);
              },
            ),
            _buildOptionTile(
              icon: Icons.gavel,
              title: 'Ban (20 days)',
              iconColor: Colors.red[900]!,
              onTap: () {
                Navigator.pop(context);
                _banMember(member);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _promoteMember(Map<String, dynamic> member, String role) async {
    final result = await _adminService.promoteMember(
      communityId: widget.communityId,
      userId: member['user_id'],
      role: role,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _loadMembers();
      }
    }
  }

  Future<void> _restrictMember(Map<String, dynamic> member, bool restrict) async {
    String? reason;

    if (restrict) {
      reason = await _showReasonDialog('Restrict Member');
      if (reason == null) return; // User cancelled
    }

    final result = await _adminService.restrictMember(
      communityId: widget.communityId,
      userId: member['user_id'],
      restrict: restrict,
      reason: reason,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _loadMembers();
      }
    }
  }

  Future<void> _kickMember(Map<String, dynamic> member) async {
    final confirmed = await _showConfirmDialog(
      'Kick Member',
      'Are you sure you want to remove ${member['username']} from this community?',
    );

    if (!confirmed) return;

    final result = await _adminService.kickMember(
      communityId: widget.communityId,
      userId: member['user_id'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _loadMembers();
      }
    }
  }

  Future<void> _banMember(Map<String, dynamic> member) async {
    final reason = await _showReasonDialog('Ban Member');
    if (reason == null) return; // User cancelled

    final confirmed = await _showConfirmDialog(
      'Ban Member',
      'Are you sure you want to ban ${member['username']} for 20 days? They will not be able to rejoin until the ban expires.',
    );

    if (!confirmed) return;

    final result = await _adminService.banMember(
      communityId: widget.communityId,
      userId: member['user_id'],
      reason: reason,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _loadMembers();
      }
    }
  }

  Future<String?> _showReasonDialog(String title) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter reason (optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.isEmpty ? 'No reason provided' : controller.text),
            child: Text('Confirm', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Confirm', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Members',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? Center(
                  child: Text(
                    'No members found',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isRestricted = member['is_restricted'] == true;
                      final isVerified = member['is_verified'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isRestricted
                              ? Border.all(color: Colors.orange, width: 2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.grey[800] : Colors.grey[200],
                              ),
                              child: ClipOval(
                                child: member['avatar_url'] != null
                                    ? (member['avatar_url'].toString().contains('.svg') || 
                                       member['avatar_url'].toString().contains('dicebear'))
                                        ? SvgPicture.network(
                                            member['avatar_url'],
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            member['avatar_url'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(
                                                child: Text(
                                                  member['username'][0].toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: isDark ? Colors.white : Colors.black,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                    : Center(
                                        child: Text(
                                          member['username'][0].toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // User info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        member['username'],
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      if (isVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: member['role'] == 'admin'
                                              ? Colors.blue.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          member['role'].toString().toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: member['role'] == 'admin'
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (isRestricted) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'RESTRICTED',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Admin actions
                            if (widget.isAdmin && member['role'] != 'admin')
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _showMemberOptions(member),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
