# User Activity & Messaging Features Implementation Guide

## Overview
This document describes the implementation of three new features:
1. **Active User Status**: Green dot indicator on chat avatars for users actively using the app
2. **Active Community Members**: Real-time "active now" count on community cards
3. **Unread Message Badge**: Notification badge on bottom navigation chat icon

## Database Changes

### New Table: `user_activity`
Tracks when users were last active in the app.

```sql
CREATE TABLE public.user_activity (
    user_id UUID PRIMARY KEY,
    last_active_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

### New Database Functions

1. **`update_user_activity()`**: Updates current user's last active timestamp
2. **`is_user_active(user_id)`**: Returns true if user was active within 5 minutes
3. **`get_active_community_members(community_id)`**: Returns count of active members in a community
4. **`get_users_activity_status(user_ids[])`**: Batch query to get activity status for multiple users

## Flutter Implementation

### New Service: `UserActivityService`

Located at: `lib/services/user_activity_service.dart`

**Key Methods:**
- `startTracking()`: Starts periodic activity updates (every 2 minutes)
- `stopTracking()`: Stops activity tracking
- `updateActivity()`: Manually updates last active timestamp
- `isUserActive(userId)`: Checks if a specific user is active
- `getUsersActivityStatus(userIds)`: Batch check for multiple users
- `getActiveCommunityMembers(communityId)`: Get active count for a community
- `getUnreadMessageCount()`: Get total unread messages for current user

### Modified Files

#### 1. `lib/chat/chat_screen.dart`
- **Changes**: 
  - Added `isActive` field to `ChatUser` model
  - Fetches activity status for all chat users
  - Green dot only shows when `user.isActive == true`
  - Preserves activity status when updating unread counts

#### 2. `lib/communities/communities_screen.dart`
- **Changes**:
  - Fetches real active member count using `UserActivityService`
  - Displays actual active count instead of mock data
  - Updates `active_count` field for each community

#### 3. `lib/main screens/main_screen.dart`
- **Changes**:
  - Starts activity tracking on app initialization
  - Adds `WidgetsBindingObserver` to track app lifecycle
  - Fetches and displays unread message count
  - New `_buildNavItemWithBadge()` method for chat icon with badge
  - Updates activity on app resume
  - Refreshes unread count when switching to chat tab

## How It Works

### Active User Detection
1. App calls `UserActivityService().startTracking()` on startup
2. Every 2 minutes, app updates `last_active_at` in database
3. User is considered "active" if `last_active_at` is within last 5 minutes
4. Green dot appears on chat avatars only for active users

### Active Community Members
1. When loading communities, app calls `getActiveCommunityMembers(communityId)`
2. Function counts members who have been active within last 5 minutes
3. Real count is displayed as "X active now" on community cards

### Unread Message Badge
1. App fetches unread count on:
   - Initial app load
   - App resume from background
   - When switching to chat tab
2. Badge displays count on chat icon in bottom navigation
3. Badge shows "99+" for counts over 99

## Activity Lifecycle

```
App Start
  ↓
UserActivityService.startTracking()
  ↓
Timer: Every 2 minutes → update_user_activity()
  ↓
User seen as "active" for 5 minutes from last update
  ↓
App Closed/Background
  ↓
Timer stops → User becomes inactive after 5 minutes
```

## Migration Steps

1. Run the SQL migration:
   ```bash
   # Execute user_activity_migration.sql in Supabase SQL Editor
   ```

2. The Flutter code is already integrated and will:
   - Automatically start tracking on app launch
   - Show green dots for active users
   - Display real active counts in communities
   - Show unread message badges

## Testing

### Test Active Status
1. Open app on two devices with different users
2. Both should see green dots on each other's avatars in chat
3. Close one app and wait 5 minutes
4. Green dot should disappear for the closed app's user

### Test Active Community Count
1. Have multiple users join a community
2. Open community discovery screen
3. "Active now" count should reflect users currently using the app

### Test Unread Badge
1. Receive a message while on a different screen
2. Chat icon should show badge with unread count
3. Open chat and read message
4. Badge should clear when returning to other screens

## Performance Considerations

- Activity updates are batched (every 2 minutes) to minimize database writes
- Activity status queries are optimized with indexes
- Batch queries used for checking multiple users at once
- 5-minute activity window balances accuracy vs performance

## Security

- RLS policies ensure:
  - Users can only update their own activity
  - All users can view activity (needed for online status)
  - Activity functions use SECURITY DEFINER with proper auth checks
