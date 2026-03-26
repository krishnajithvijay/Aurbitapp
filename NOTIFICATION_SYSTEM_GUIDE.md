# Notification System Implementation Guide

## Overview
The notification system automatically creates notifications for:
- **Reactions** on posts (I Relate / You're Not Alone)
- **Comments** on posts
- **Replies** to comments
- **Orbit Requests** (friend requests for Inner/Outer orbit)

## Database Setup

### 1. Run the Migration
Execute the `notifications_migration.sql` file in your Supabase SQL editor:
```bash
# The migration creates:
- notifications table
- Automatic triggers for reactions, comments, and replies
- Helper functions for marking as read
- RLS policies for security
```

## Features Implemented

### Automatic Notifications
The system uses PostgreSQL triggers to automatically create notifications when:
1. Someone reacts to your post
2. Someone comments on your post
3. Someone replies to your comment

### Notification Types
- `reaction` - When someone reacts to your post
- `comment` - When someone comments on your post
- `reply` - When someone replies to your comment
- `orbit_request` - Friend request (manual creation)
- `orbit_accept` - When someone accepts your request
- `message` - For future messaging feature

### Notification Screen Features
✅ Beautiful card-based UI matching your design
✅ Avatar with icon badge showing notification type
✅ Unread indicator (blue dot)
✅ Time ago display (2m ago, 5h ago, etc.)
✅ Mark all as read button
✅ Pull to refresh
✅ Tap notification to view related post
✅ Accept/Decline buttons for orbit requests
✅ Choose Inner or Outer orbit when accepting

### Real-time Updates
The notification count badge updates automatically when:
- New notifications arrive
- User marks notifications as read
- User returns from notification screen

## Usage

### Displaying Notification Count
The notification bell in `space_screen.dart` shows an unread count badge:
```dart
// Already implemented in space_screen.dart
_fetchNotificationCount(); // Fetches unread count
```

### Navigating to Notifications
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NotificationScreen(),
  ),
);
```

### Creating Manual Notifications (Orbit Requests)
```dart
// Send orbit request notification
await NotificationService().createOrbitRequestNotification(
  recipientId: 'user-uuid',
  orbitType: 'inner', // or 'outer'
);

// Send orbit accept notification
await NotificationService().createOrbitAcceptNotification(
  recipientId: 'user-uuid',
  orbitType: 'inner',
);
```

### Subscribing to Real-time Notifications (Optional)
```dart
final channel = NotificationService().subscribeToNotifications((notification) {
  // Handle new notification
  print('New notification: ${notification['title']}');
  // Update UI, show toast, etc.
});

// Don't forget to unsubscribe
Supabase.instance.client.removeChannel(channel);
```

## Notification Flow

### 1. Reaction Notification
```
User A reacts to User B's post
  ↓
Trigger: notify_post_reaction()
  ↓
Notification created: "User A related to your post"
  ↓
User B sees notification with heart icon
  ↓
Taps notification → Opens post detail screen
```

### 2. Comment Notification
```
User A comments on User B's post
  ↓
Trigger: notify_post_comment()
  ↓
Notification created: "User A commented on your post"
  ↓
User B sees notification with comment icon
  ↓
Taps notification → Opens post detail screen
```

### 3. Reply Notification
```
User A replies to User B's comment
  ↓
Trigger: notify_comment_reply()
  ↓
Notification created: "User A replied to your comment"
  ↓
User B sees notification with reply icon
  ↓
Taps notification → Opens post detail screen
```

### 4. Orbit Request Flow
```
User A sends orbit request to User B
  ↓
Manual: createOrbitRequestNotification()
  ↓
User B sees notification with person-add icon
  ↓
User B taps "Accept" → Choose Inner/Outer orbit
  ↓
Notification sent back to User A: "User B added you to their Inner Orbit"
```

## Customization

### Changing Notification Colors
Edit `_getIconColor()` in `notification_screen.dart`:
```dart
Color _getIconColor(String type, bool isDark) {
  switch (type) {
    case 'reaction':
      return Colors.red; // Change to your preferred color
    case 'comment':
      return Colors.blue;
    // ... etc
  }
}
```

### Changing Notification Icons
Edit `_getNotificationIcon()` in `notification_screen.dart`:
```dart
IconData _getNotificationIcon(String type) {
  switch (type) {
    case 'reaction':
      return Icons.favorite_rounded; // Change icon
    // ... etc
  }
}
```

## Database Queries

### Get all notifications for a user
```sql
SELECT * FROM notifications 
WHERE recipient_id = 'user-uuid' 
ORDER BY created_at DESC;
```

### Get unread count
```sql
SELECT COUNT(*) FROM notifications 
WHERE recipient_id = 'user-uuid' 
AND is_read = false;
```

### Mark all as read
```sql
UPDATE notifications 
SET is_read = true 
WHERE recipient_id = 'user-uuid' 
AND is_read = false;
```

## Troubleshooting

### Notifications not appearing?
1. Check if triggers are created: `\df` in psql
2. Verify RLS policies are enabled
3. Check user authentication
4. Look for errors in Supabase logs

### Duplicate notifications?
The system has a UNIQUE constraint to prevent duplicates:
```sql
UNIQUE(recipient_id, sender_id, type, post_id, comment_id)
```

### Notification count not updating?
- Ensure `_fetchNotificationCount()` is called after actions
- Check if RLS policies allow reading notifications
- Verify user is authenticated

## Next Steps

### To implement orbit/friend system:
1. Create `orbits` or `friendships` table
2. Add orbit management in notification handler
3. Update `_handleOrbitRequest()` to save to database
4. Create orbit management screen

### To add push notifications:
1. Integrate Firebase Cloud Messaging (FCM)
2. Store FCM tokens in profiles table
3. Create cloud function to send push notifications
4. Trigger on notification insert

## Files Created
- `notifications_migration.sql` - Database schema and triggers
- `lib/services/notification_service.dart` - Service layer
- `lib/notifications/notification_screen.dart` - UI screen
- Updated `lib/space/space_screen.dart` - Integration

## Testing Checklist
- [ ] Run migration in Supabase
- [ ] React to a post → Check notification appears
- [ ] Comment on a post → Check notification appears
- [ ] Reply to a comment → Check notification appears
- [ ] Tap notification → Opens correct post
- [ ] Mark as read → Blue dot disappears
- [ ] Mark all as read → All notifications marked
- [ ] Notification count badge updates correctly
