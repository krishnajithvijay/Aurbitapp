# Community Posts System Implementation Guide

## Overview
A complete community posting system that allows members to create posts within communities they've joined, with tracking of members, usernames, join dates, and a warning dialog when leaving.

## Database Schema

### Tables Created

#### 1. `community_members`
Tracks which users are members of which communities.

**Columns:**
- `id` - UUID primary key
- `community_id` - Reference to communities table
- `user_id` - Reference to profiles table
- `username` - User's username (denormalized for performance)
- `role` - User role: 'admin', 'moderator', or 'member'
- `joined_at` - Timestamp when user joined

**Features:**
- Unique constraint on (community_id, user_id)
- Automatic member count updates via triggers
- RLS policies for security

#### 2. `community_posts`
Posts created by members within communities.

**Columns:**
- `id` - UUID primary key
- `community_id` - Reference to communities table
- `user_id` - Reference to profiles table (post author)
- `content` - Post text content
- `mood` - Optional mood (Happy, Stressed, Peaceful, etc.)
- `is_anonymous` - Boolean for anonymous posting
- `created_at` - Post creation timestamp
- `updated_at` - Last update timestamp

**Features:**
- Only members can post (enforced by RLS)
- Anonymous posting support
- Mood tracking

## Files Created

### 1. Database Migration
**File:** `community_members_migration.sql`

**Features:**
- Creates both tables with proper relationships
- Sets up RLS policies
- Creates helper functions:
  - `get_community_member_count()`
  - `is_community_member()`
  - `get_community_posts_with_users()`
- Automatic triggers for member count updates
- Adds `member_count` column to communities table

### 2. Community Service
**File:** `lib/services/community_service.dart`

**Methods:**
- `joinCommunity(communityId)` - Join a community
- `leaveCommunity(communityId)` - Leave a community
- `isMember(communityId)` - Check membership status
- `getCommunityMembers(communityId)` - Fetch all members
- `getCommunityPosts(communityId)` - Fetch community posts
- `showLeaveCommunityDialog()` - Warning dialog before leaving

### 3. Create Post Screen
**File:** `lib/community/create_community_post_screen.dart`

**Features:**
- ✅ Community info display
- ✅ Multi-line text input
- ✅ Mood selection (8 moods with emojis)
- ✅ Anonymous posting toggle
- ✅ Community guidelines notice
- ✅ Post validation
- ✅ Member-only posting (enforced)

### 4. Community Feed Screen
**File:** `lib/community/community_feed_screen.dart`

**Features:**
- ✅ Community header with icon
- ✅ Member count and active status
- ✅ Join/Leave button
- ✅ Recent posts list
- ✅ Post creation FAB (members only)
- ✅ Empty state for non-members
- ✅ Pull to refresh
- ✅ Warning dialog on leave

## Usage

### 1. Run the Migration
Execute `community_members_migration.sql` in Supabase SQL editor.

### 2. Navigate to Community Feed
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CommunityFeedScreen(
      community: {
        'id': 'community-uuid',
        'name': 'Mindful Moments',
        'description': 'Share your mindfulness journey...',
      },
    ),
  ),
);
```

### 3. Create a Post (Members Only)
```dart
// From Community Feed Screen
// Tap FAB or + icon
// Opens CreateCommunityPostScreen
```

## Features Breakdown

### Join Community Flow
```
User taps "Join Community"
  ↓
CommunityService.joinCommunity()
  ↓
Insert into community_members table
  ↓
Trigger updates member_count
  ↓
UI updates to show "Leave Community" button
  ↓
User can now create posts
```

### Leave Community Flow
```
User taps "Leave Community"
  ↓
Warning dialog appears
  ↓
Shows consequences:
  - Lose access to posts
  - No community updates
  - Need to rejoin to post
  ↓
User confirms
  ↓
CommunityService.leaveCommunity()
  ↓
Delete from community_members
  ↓
Trigger updates member_count
  ↓
UI updates to show "Join Community" button
```

### Create Post Flow
```
Member taps FAB
  ↓
CreateCommunityPostScreen opens
  ↓
User writes content
  ↓
Selects mood (optional)
  ↓
Toggles anonymous (optional)
  ↓
Taps "Post" button
  ↓
Validates membership
  ↓
Inserts into community_posts
  ↓
Returns to feed with new post
```

## Warning Dialog

The leave community dialog shows:
- ⚠️ Warning icon
- Community name
- List of consequences
- Cancel button
- "Leave Community" button (red)

**Implementation:**
```dart
final shouldLeave = await CommunityService.showLeaveCommunityDialog(
  context,
  communityName,
);

if (shouldLeave) {
  // Proceed with leaving
}
```

## Post Card Features

### For Members:
- Full post content
- Author avatar and username
- Mood badge
- Time ago
- Like and comment options (future)

### For Non-Members:
- Post preview
- Lock icon with message
- "Join the community to like and comment"

## Anonymous Posting

When `is_anonymous` is true:
- Username shows as "Anonymous"
- Avatar is hidden
- User identity is protected in UI
- Database still tracks user_id for moderation

## Mood Options

Available moods with emojis:
- 🤩 Happy
- 🤯 Stressed
- 😴 Tired
- 😤 Irritated
- 😶‍🌫️ Lonely
- 😑 Bored
- 😌 Peaceful
- 🙏 Grateful

## Database Queries

### Get all members of a community
```sql
SELECT * FROM community_members
WHERE community_id = 'uuid'
ORDER BY joined_at DESC;
```

### Get member count
```sql
SELECT get_community_member_count('community-uuid');
```

### Check if user is member
```sql
SELECT is_community_member('community-uuid', 'user-uuid');
```

### Get community posts with user info
```sql
SELECT * FROM get_community_posts_with_users('community-uuid');
```

## Security (RLS Policies)

### community_members
- ✅ Anyone can view members
- ✅ Users can join (insert own membership)
- ✅ Users can leave (delete own membership)
- ✅ Only admins can update roles

### community_posts
- ✅ Anyone can view posts
- ✅ Only members can create posts
- ✅ Users can update own posts
- ✅ Users can delete own posts

## Customization

### Change Moods
Edit `_moods` list in `create_community_post_screen.dart`:
```dart
final List<Map<String, dynamic>> _moods = [
  {'name': 'Custom Mood', 'emoji': '😊'},
  // Add more...
];
```

### Customize Warning Dialog
Edit `showLeaveCommunityDialog()` in `community_service.dart`.

### Add Post Reactions
1. Create `community_post_reactions` table
2. Add reaction buttons to post cards
3. Update RLS policies

## Integration with Existing Code

### Update Community Discovery Screen
Add navigation to CommunityFeedScreen when tapping a community:
```dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CommunityFeedScreen(
        community: community,
      ),
    ),
  );
}
```

### Add to Navigation
If you want a dedicated communities tab, add to bottom navigation.

## Testing Checklist

- [ ] Run migration in Supabase
- [ ] Join a community → Check member count increases
- [ ] Create a post as member → Post appears in feed
- [ ] Try to create post as non-member → Should fail
- [ ] Leave community → Warning dialog appears
- [ ] Confirm leave → Member count decreases
- [ ] Test anonymous posting → Username shows "Anonymous"
- [ ] Test mood selection → Mood badge appears
- [ ] Pull to refresh → Posts reload
- [ ] Check RLS policies → Non-members can't post

## Troubleshooting

### Posts not appearing?
- Check if user is a member
- Verify RLS policies are enabled
- Check Supabase logs for errors

### Can't join community?
- Ensure user is authenticated
- Check if already a member
- Verify foreign key constraints

### Member count not updating?
- Check if triggers are created
- Verify `member_count` column exists
- Run manual update query

## Next Steps

### Recommended Enhancements:
1. **Post Reactions** - Like/support system
2. **Comments** - Allow members to comment on posts
3. **Post Editing** - Edit posts within time limit
4. **Moderation** - Report/flag inappropriate posts
5. **Notifications** - Notify on new posts
6. **Search** - Search within community posts
7. **Pinned Posts** - Pin important announcements
8. **Member Roles** - Different permissions for admins/mods

## Files Summary

```
a:\aurbitapp\
├── community_members_migration.sql
├── lib\
│   ├── services\
│   │   └── community_service.dart
│   └── community\
│       ├── create_community_post_screen.dart
│       └── community_feed_screen.dart
```

All files are production-ready with proper error handling, loading states, and beautiful UI! 🎉
