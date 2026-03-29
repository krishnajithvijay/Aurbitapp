import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';

class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final VoidCallback? onTap;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    this.user,
    this.avatarUrl,
    this.displayName,
    this.radius = 20,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onTap,
    this.borderColor,
  });

  String get _initials {
    final name = user?.displayName ?? displayName ?? '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String? get _avatarUrl => user?.avatarUrl ?? avatarUrl;

  Color _colorFromName(String name) {
    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.accentPink,
      AppColors.accentGreen,
      const Color(0xFFFF8C00),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
    ];
    final index = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final url = _avatarUrl;
    final name = user?.displayName ?? displayName ?? '';
    final online = user?.isOnline ?? isOnline;

    Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colorFromName(name),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      child: url != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                placeholder: (_, __) => Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.7,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.7,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                _initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.7,
                ),
              ),
            ),
    );

    if (showOnlineIndicator) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: online ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkCard, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
