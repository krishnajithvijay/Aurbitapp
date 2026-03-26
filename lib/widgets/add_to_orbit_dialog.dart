import 'package:flutter/material.dart';
import '../models/user_orbit.dart';
import '../services/orbit_service.dart';

class AddToOrbitDialog extends StatefulWidget {
  final String userId;
  final String username;
  final String? avatarUrl;
  final VoidCallback? onAdded;

  const AddToOrbitDialog({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.onAdded,
  });

  @override
  State<AddToOrbitDialog> createState() => _AddToOrbitDialogState();
}

class _AddToOrbitDialogState extends State<AddToOrbitDialog> {
  final _orbitService = OrbitService();
  bool _isLoading = false;

  Future<void> _addToOrbit(OrbitType type) async {
    setState(() => _isLoading = true);
    try {
      await _orbitService.sendOrbitRequest(widget.userId, type.value);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to ${widget.username}!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
             Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.grey[800] : Colors.grey[600],
              ),
              child: ClipOval(
                child: widget.avatarUrl != null
                    ? Image.network(
                        widget.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 40),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),

            // Username
            Text(
              widget.username,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Question Text
            Text(
              'Add to which orbit?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  // Inner Orbit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _addToOrbit(OrbitType.inner),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black, // Dark/Black background
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radio_button_checked, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Inner Orbit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Outer Orbit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => _addToOrbit(OrbitType.outer),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radio_button_unchecked, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Outer Orbit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 20),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
