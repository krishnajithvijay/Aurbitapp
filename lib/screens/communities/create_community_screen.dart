import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _db = SupabaseService.instance;
  bool _loading = false;
  bool _isPrivate = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final newComm = await _db.client.from(AppConstants.communitiesTable).insert({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'created_by': userId,
        'is_private': _isPrivate,
        'member_count': 1,
        'post_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      // Auto-join creator as admin
      await _db.client.from(AppConstants.communityMembersTable).insert({
        'community_id': newComm['id'],
        'user_id': userId,
        'role': 'admin',
        'joined_at': DateTime.now().toIso8601String(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(title: const Text('Create Community')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Community icon preview
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'C',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AppTextField(
                controller: _nameCtrl,
                label: 'Community Name',
                hint: 'e.g. Flutter Developers',
                prefixIcon: Icons.group_rounded,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name required';
                  if (v.trim().length < 3) return 'Minimum 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descCtrl,
                label: 'Description (optional)',
                hint: 'What is this community about?',
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Private Community', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Text(
                          'Only invited members can join',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    onChanged: (v) => setState(() => _isPrivate = v),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Create Community',
                isLoading: _loading,
                onPressed: _create,
                gradient: AppColors.primaryGradient,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
