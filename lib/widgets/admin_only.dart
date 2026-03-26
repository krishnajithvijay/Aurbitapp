import 'package:flutter/material.dart';
import '../services/community_admin_service.dart';

/// A widget that conditionally shows its child only if the current user is an admin
/// of the specified community. Useful for showing/hiding admin-only UI elements.
class AdminOnly extends StatefulWidget {
  final String communityId;
  final Widget child;
  final Widget? fallback;

  const AdminOnly({
    super.key,
    required this.communityId,
    required this.child,
    this.fallback,
  });

  @override
  State<AdminOnly> createState() => _AdminOnlyState();
}

class _AdminOnlyState extends State<AdminOnly> {
  final _adminService = CommunityAdminService();
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin(widget.communityId);
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_isAdmin) {
      return widget.child;
    }

    return widget.fallback ?? const SizedBox.shrink();
  }
}

/// A FutureBuilder-based widget that provides admin status in the builder
/// Use this when you need to build different UI based on admin status
class AdminAware extends StatelessWidget {
  final String communityId;
  final Widget Function(BuildContext context, bool isAdmin) builder;

  const AdminAware({
    super.key,
    required this.communityId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: CommunityAdminService().isAdmin(communityId),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;
        return builder(context, isAdmin);
      },
    );
  }
}
