import 'package:flutter/material.dart';

/// A reusable widget that displays a verification badge (blue tick) next to usernames
/// Use this widget throughout the app wherever you display usernames
class VerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final double size;
  final Color? color;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.verified,
        color: color ?? Colors.blue,
        size: size,
      ),
    );
  }
}

/// A widget that displays username with optional verification badge
class UsernameWithBadge extends StatelessWidget {
  final String username;
  final bool isVerified;
  final TextStyle? textStyle;
  final double badgeSize;
  final Color? badgeColor;

  const UsernameWithBadge({
    super.key,
    required this.username,
    this.isVerified = false,
    this.textStyle,
    this.badgeSize = 16,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            username,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        VerifiedBadge(
          isVerified: isVerified,
          size: badgeSize,
          color: badgeColor,
        ),
      ],
    );
  }
}
