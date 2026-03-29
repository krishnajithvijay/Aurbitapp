import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  const CreatePostScreen({super.key, this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final _db = SupabaseService.instance;
  File? _selectedImage;
  bool _loading = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _selectedImage = File(file.path));
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first!')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final userId = AuthService.instance.currentUserId!;
      String? mediaUrl;

      if (_selectedImage != null) {
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _db.storage.from(AppConstants.postMediaBucket).upload(fileName, _selectedImage!);
        mediaUrl = _db.storage.from(AppConstants.postMediaBucket).getPublicUrl(fileName);
      }

      await _db.client.from(AppConstants.postsTable).insert({
        'user_id': userId,
        'community_id': widget.communityId,
        'content': content,
        'media_url': mediaUrl,
        'media_type': _selectedImage != null ? 'image' : null,
        'likes_count': 0,
        'comments_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(
        backgroundColor: AppColors.oledBlack,
        title: const Text('New Post'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: AppButton(
              text: 'Post',
              isLoading: _loading,
              onPressed: _submit,
              width: 80,
              height: 36,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        avatarUrl: null,
                        displayName: user?.email ?? 'U',
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _contentCtrl,
                          maxLines: null,
                          autofocus: true,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                height: 1.5,
                              ),
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.textMuted, fontSize: 16),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!, height: 220, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
              color: AppColors.darkCard,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  _ActionBtn(icon: Icons.image_outlined, label: 'Photo', onTap: _pickImage),
                  const SizedBox(width: 20),
                  _ActionBtn(icon: Icons.mood_rounded, label: 'Feeling', onTap: () {}),
                  const SizedBox(width: 20),
                  _ActionBtn(icon: Icons.location_on_outlined, label: 'Location', onTap: () {}),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
