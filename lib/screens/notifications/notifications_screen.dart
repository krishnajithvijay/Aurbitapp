import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/community_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common/user_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = SupabaseService.instance;
  final List<NotificationModel> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToNotifs();
  }

  void _subscribeToNotifs() {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    _db.client
        .channel('notifs_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _load() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final data = await _db.client
          .from(AppConstants.notificationsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifs = <NotificationModel>[];
      for (final item in data) {
        final n = NotificationModel.fromJson(item);
        if (n.actorId != null) {
          final userRow = await _db.selectSingle(AppConstants.profilesTable, column: 'id', value: n.actorId);
          if (userRow != null) n.actor = UserModel.fromJson(userRow);
        }
        notifs.add(n);
      }

      // Mark all as read
      await _db.client
          .from(AppConstants.notificationsTable)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      setState(() {
        _notifs
          ..clear()
          ..addAll(notifs);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : _notifs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text('All caught up!', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('No new notifications', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _notifs.length,
                    itemBuilder: (ctx, i) => _NotifTile(notif: _notifs[i]),
                  ),
                ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: notif.isRead ? Colors.transparent : AppColors.primary.withOpacity(0.05),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              user: notif.actor,
              displayName: notif.actor?.displayName ?? 'System',
              radius: 22,
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkBorder, width: 1),
                ),
                child: Center(
                  child: Text(notif.icon, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          notif.title ?? _defaultTitle(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.body != null)
              Text(
                notif.body!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              timeago.format(notif.createdAt),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        trailing: notif.isRead ? null : Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _defaultTitle() {
    final actorName = notif.actor?.displayName ?? 'Someone';
    switch (notif.type) {
      case 'like':
        return '$actorName liked your post';
      case 'comment':
        return '$actorName commented on your post';
      case 'orbit_request':
        return '$actorName wants to orbit you';
      case 'orbit_accepted':
        return '$actorName accepted your orbit request';
      case 'message':
        return '$actorName sent you a message';
      default:
        return 'New notification';
    }
  }
}
