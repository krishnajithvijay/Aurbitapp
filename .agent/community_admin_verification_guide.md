# Community Admin Features & Verification Implementation Guide

This document provides a comprehensive guide to implementing the community admin features and verification system in the Aurbit app.

## Overview

Three major features have been implemented:

1. **Community Admin Features**
   - Change community name and bio
   - View all community members
   - Kick members (force leave)
   - Ban members (20-day ban)
   - Restrict members (prevent posting)
   - Promote members to admin

2. **Community Database Enhancements**
   - Added `bio` column to communities table
   - Created `community_bans` table for tracking bans
   - Added restriction fields to `community_members` table
   - Enhanced RLS policies for admin operations

3. **Verification Blue Tick Feature**
   - Added `is_verified` column to profiles table
   - Created reusable `VerifiedBadge` widget
   - Verification appears throughout the app

## Files Created

### SQL Migrations

1. **`community_admin_features_migration.sql`**
   - Adds bio column to communities
   - Creates community_bans table
   - Adds restriction columns to community_members
   - Implements RLS policies for admin operations
   - Creates helper functions for ban checking and member management

2. **`user_verification_migration.sql`**
   - Adds is_verified, verified_at, and verification_type columns to profiles
   - Creates verification_requests table
   - Implements functions for granting/revoking verification
   - Sets up RLS policies

### Dart Files

1. **`lib/services/community_admin_service.dart`**
   - `isAdmin()` - Check if user is admin
   - `updateCommunityInfo()` - Update name and bio
   - `getMembersWithDetails()` - Get members with full details
   - `kickMember()` - Remove member from community
   - `banMember()` - Ban member for 20 days
   - `restrictMember()` - Restrict/unrestrict posting
   - `promoteMember()` - Change member role
   - `checkBanStatus()` - Check if user is banned
   - `unbanMember()` - Remove ban
   - `getBannedMembers()` - Get list of banned users

2. **`lib/community/community_members_screen.dart`**
   - Full-featured members management screen
   - Shows all members with roles and status
   - Admin options bottom sheet
   - Handles kick, ban, restrict, and promote actions
   - Shows verification badges for verified users

3. **`lib/community/community_settings_screen.dart`**
   - Edit community name and bio
   - Form validation
   - Save functionality with feedback

4. **`lib/widgets/verified_badge.dart`**
   - `VerifiedBadge` - Simple verified icon widget
   - `UsernameWithBadge` - Username with inline badge
   - Reusable across the entire app

5. **`lib/widgets/ban_warning_dialog.dart`**
   - Shows ban information when user tries to join
   - Displays days remaining and reason
   - Clean, modern UI

6. **Updated: `lib/services/community_service.dart`**
   - Enhanced `joinCommunity()` to check for bans
   - Returns detailed response with ban information
   - Added `checkBanStatus()` method

## Database Schema Changes

### Communities Table
```sql
ALTER TABLE communities ADD COLUMN bio TEXT;
```

### Community Bans Table (New)
```sql
CREATE TABLE community_bans (
    id UUID PRIMARY KEY,
    community_id UUID REFERENCES communities(id),
    user_id UUID REFERENCES profiles(id),
    banned_by UUID REFERENCES profiles(id),
    banned_at TIMESTAMP,
    ban_expires_at TIMESTAMP (defaults to NOW() + 20 days),
    reason TEXT
);
```

### Community Members Table (Updated)
```sql
ALTER TABLE community_members ADD COLUMN:
- is_restricted BOOLEAN DEFAULT FALSE
- restricted_by UUID REFERENCES profiles(id)
- restricted_at TIMESTAMP
- restriction_reason TEXT
```

### Profiles Table (Updated)
```sql
ALTER TABLE profiles ADD COLUMN:
- is_verified BOOLEAN DEFAULT FALSE
- verified_at TIMESTAMP
- verification_type TEXT ('standard', 'premium', 'official')
```

## Implementation Steps

### Step 1: Run SQL Migrations

Execute both SQL migration files in your Supabase SQL editor:

1. Run `community_admin_features_migration.sql`
2. Run `user_verification_migration.sql`

These will create all necessary tables, columns, functions, and policies.

### Step 2: Add Verification Badges Throughout the App

The `VerifiedBadge` widget can be used anywhere you display usernames:

```dart
import 'package:aurbitapp/widgets/verified_badge.dart';

// Option 1: Simple badge next to username
Row(
  children: [
    Text(username),
    VerifiedBadge(isVerified: user['is_verified'] ?? false),
  ],
)

// Option 2: Complete username with badge component
UsernameWithBadge(
  username: user['username'],
  isVerified: user['is_verified'] ?? false,
  textStyle: GoogleFonts.inter(fontSize: 16),
)
```

**Files to update with verification badges:**
- `lib/space/feed_post_card.dart` - In post author display
- `lib/community/community_post_detail_screen.dart` - In post and comment authors
- `lib/profile/profile_screen.dart` - In user's own profile
- Any other screens showing usernames

### Step 3: Integrate Community Members Screen

Add navigation to the members screen from your community feed:

```dart
// In your community feed screen
IconButton(
  icon: Icon(Icons.people),
  onPressed: () async {
    final isAdmin = await CommunityAdminService().isAdmin(communityId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityMembersScreen(
          communityId: communityId,
          communityName: communityName,
          isAdmin: isAdmin,
        ),
      ),
    );
  },
)
```

### Step 4: Add Community Settings Access

Add a settings button for admins:

```dart
// Check if user is admin
final adminService = CommunityAdminService();
final isAdmin = await adminService.isAdmin(communityId);

if (isAdmin) {
  IconButton(
    icon: Icon(Icons.settings),
    onPressed: () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommunitySettingsScreen(
            communityId: communityId,
            currentName: communityName,
            currentBio: communityBio,
          ),
        ),
      );
      
      // If result is true, refresh the community data
      if (result == true) {
        // Reload community info
      }
    },
  );
}
```

### Step 5: Update Join Community Logic

Update your existing join community button to handle ban warnings:

```dart
import 'package:aurbitapp/widgets/ban_warning_dialog.dart';

// Replace your existing join logic
final result = await CommunityService().joinCommunity(communityId);

if (result['success']) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result['message'])),
  );
  // Refresh UI
} else if (result['banned'] == true) {
  // Show ban warning
  await BanWarningDialog.show(
    context: context,
    daysRemaining: result['banInfo']['days_remaining'],
    reason: result['banInfo']['reason'],
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result['message']),
      backgroundColor: Colors.red,
    ),
  );
}
```

### Step 6: Update Member Queries to Include Verification

Wherever you fetch user profiles, include the `is_verified` field:

```dart
final response = await _supabase
    .from('profiles')
    .select('id, username, avatar_url, is_verified')
    .eq('id', userId)
    .single();
```

Or in joins:

```dart
final response = await _supabase
    .from('community_posts')
    .select('''
      *,
      profile:user_id(id, username, avatar_url, is_verified)
    ''')
    .eq('community_id', communityId);
```

## Key Features Explained

### 1. Kick vs Ban

- **Kick**: Removes user from community, they can rejoin immediately
- **Ban**: Removes user AND prevents rejoining for 20 days
  - Database trigger prevents banned users from joining
  - Ban automatically expires after 20 days
  - Admins can manually unban users

### 2. Restrict

- Restricted users remain in the community
- They can view posts and comments
- They cannot create new posts
- RLS policy enforces this at database level
- Shows "RESTRICTED" badge in members list

### 3. Promote to Admin

- Admins can change any member's role
- Roles: `member`, `moderator`, `admin`
- Multiple admins are supported
- Original creator maintains full ownership (via `created_by` field)

### 4. Verification Badge

- Displays blue checkmark next to verified users
- Visible throughout the entire app
- Can be granted via SQL function:
  ```sql
  SELECT grant_verification('user-uuid', 'standard');
  ```
- Can be revoked:
  ```sql
  SELECT revoke_verification('user-uuid');
  ```

## Testing the Features

### Test Admin Features

1. Create a test community
2. Have another user join
3. Test each admin action:
   - Edit name/bio in settings
   - View members list
   - Restrict a member (try to post as them - should fail)
   - Unrestrict a member
   - Kick a member (they should be able to rejoin)
   - Ban a member (they should see warning when trying to rejoin)
   - Promote a member to admin

### Test Verification

1. Grant verification to a test user:
   ```sql
   SELECT grant_verification(
     (SELECT id FROM profiles WHERE username = 'testuser'),
     'standard'
   );
   ```
2. Check that blue tick appears everywhere the username is shown
3. Test on different screens: feed, comments, members list, etc.

### Test Ban System

1. Ban a user from a community
2. Try to join as that user - should see warning dialog
3. Wait for ban to expire (or manually delete from `community_bans`)
4. User should be able to join again

## Security Considerations

All admin actions are protected by Row Level Security (RLS) policies:

- Only admins can kick, ban, restrict, or promote members
- Only admins can update community info
- Users can only leave communities themselves
- Banned users are prevented from joining at database level
- Restricted users cannot post (enforced by RLS)

## Troubleshooting

### "User is not admin" error
- Check that user's role in `community_members` table is 'admin'
- Verify RLS policies are enabled

### Ban not working
- Ensure `community_admin_features_migration.sql` was run completely
- Check that `trigger_check_community_ban` exists
- Verify ban_expires_at is in the future

### Verification badge not showing
- Ensure `user_verification_migration.sql` was run
- Check that `is_verified` is included in profile queries
- Verify VerifiedBadge widget is properly imported

### Restricted user can still post
- Check RLS policy on `community_posts` table
- Ensure `is_restricted` field is properly set
- Verify community status is 'active'

## Future Enhancements

Potential additions to consider:

1. **Moderator Role**: Implement different permissions for moderators vs admins
2. **Ban Duration**: Allow custom ban durations
3. **Appeal System**: Let banned users appeal their bans
4. **Audit Log**: Track all admin actions
5. **Bulk Actions**: Ban/kick multiple users at once
6. **Verification Tiers**: Different badge colors for different verification types
7. **Auto-moderation**: Automatic restrictions based on reports
8. **Member Stats**: Show post count, join date, etc. in members list

## Questions?

If you encounter issues:
1. Check Supabase logs for RLS policy violations
2. Verify all migrations ran successfully
3. Check that all imports are correct in Dart files
4. Ensure you're fetching `is_verified` in profile queries
