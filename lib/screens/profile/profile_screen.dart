import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/feed/post_card.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = SupabaseService.instance;
  UserModel? _user;
  final List<PostModel> _posts = [];
  bool _loading = true;
  int _orbitCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      _user = await AuthService.instance.getCurrentUserProfile();
      if (_user != null) {
        // Load posts
        final data = await _db.client
            .from(AppConstants.postsTable)
            .select()
            .eq('user_id', _user!.id)
            .order('created_at', ascending: false)
            .limit(20);
        _posts
          ..clear()
          ..addAll(data.map((e) => PostModel.fromJson(e)));

        // Orbit count
        final orbitData = await _db.client
            .from(AppConstants.orbitsTable)
            .select('id', const FetchOptions(count: CountOption.exact, head: true))
            .or('requester_id.eq.${_user!.id},addressee_id.eq.${_user!.id}')
            .eq('status', 'accepted');
        _orbitCount = orbitData.count ?? 0;
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await NotificationService.instance.deleteFcmToken();
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.oledBlack,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      );
    }
    if (_user == null) {
      return const Scaffold(
        backgroundColor: AppColors.oledBlack,
        body: Center(child: Text('Could not load profile')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProfile,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildProfileInfo()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Posts', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            if (_posts.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No posts yet', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => PostCard(post: _posts[i]),
                  childCount: _posts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: AppColors.oledBlack,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: _showEditProfile,
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _signOut,
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -36),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _changeAvatar,
                  child: Stack(
                    children: [
                      UserAvatar(user: _user, radius: 40, borderColor: AppColors.oledBlack),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _user!.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (_user!.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, color: AppColors.accent, size: 18),
                    ],
                  ],
                ),
                Text('@${_user!.username}', style: Theme.of(context).textTheme.bodyMedium),
                if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_user!.bio!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(value: '${_posts.length}', label: 'Posts'),
                    const SizedBox(width: 24),
                    _StatChip(value: '$_orbitCount', label: 'In Orbit'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final userId = AuthService.instance.currentUserId!;
    final path = '$userId/avatar.jpg';
    await _db.storage.from(AppConstants.avatarsBucket).upload(path, File(file.path), fileOptions: const FileOptions(upsert: true));
    final url = _db.storage.from(AppConstants.avatarsBucket).getPublicUrl(path);
    await AuthService.instance.updateProfile(avatarUrl: url);
    _loadProfile();
  }

  void _showEditProfile() {
    final displayNameCtrl = TextEditingController(text: _user?.displayName);
    final bioCtrl = TextEditingController(text: _user?.bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            AppTextField(controller: displayNameCtrl, label: 'Display Name', prefixIcon: Icons.person_outline_rounded),
            const SizedBox(height: 14),
            AppTextField(controller: bioCtrl, label: 'Bio', hint: 'Tell people about yourself', maxLines: 3),
            const SizedBox(height: 20),
            AppButton(
              text: 'Save Changes',
              gradient: AppColors.primaryGradient,
              onPressed: () async {
                await AuthService.instance.updateProfile(
                  displayName: displayNameCtrl.text.trim(),
                  bio: bioCtrl.text.trim(),
                );
                if (mounted) Navigator.pop(ctx);
                _loadProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
