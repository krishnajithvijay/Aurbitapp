import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_orbit.dart';
import '../services/orbit_service.dart';
import '../services/mood_service.dart';

class OrbitMemberActionsSheet extends StatelessWidget {
  final UserOrbit orbitUser;
  final VoidCallback onRemove;

  const OrbitMemberActionsSheet({
    super.key,
    required this.orbitUser,
    required this.onRemove,
  });

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Text(
        orbitUser.friendUsername?[0].toUpperCase() ?? '?',
        style: TextStyle(
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = orbitUser.friendCurrentMood ?? 'Neutral';
    final moodEmoji = MoodService.getMoodEmoji(mood);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                ),
                child: ClipOval(
                  child: orbitUser.friendAvatarUrl != null
                      ? (orbitUser.friendAvatarUrl!.contains('.svg') || orbitUser.friendAvatarUrl!.contains('dicebear'))
                          ? SvgPicture.network(
                              orbitUser.friendAvatarUrl!,
                              fit: BoxFit.cover,
                              width: 48,
                              height: 48,
                              placeholderBuilder: (BuildContext context) => _buildPlaceholder(theme),
                            )
                          : Image.network(
                              orbitUser.friendAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(theme),
                            )
                      : _buildPlaceholder(theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orbitUser.friendUsername ?? 'User',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      orbitUser.isInnerOrbit ? 'Inner Orbit' : 'Outer Orbit',
                      style: TextStyle(
                        color: orbitUser.isInnerOrbit ? Colors.blueAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(moodEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Mood',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    Text(
                      mood,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close sheet
                _confirmRemove(context);
              },
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Remove from Orbit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Orbit?'),
        content: Text('Are you sure you want to remove ${orbitUser.friendUsername} from your orbit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              onRemove();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
