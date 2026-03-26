# Delete Feature - Quick Reference

## How to Delete Posts

### In Feed View:
1. **Long-press** on any post you created
2. A dialog will appear asking "Delete Post?"
3. Tap **Delete** to confirm or **Cancel** to dismiss
4. Post will be removed and you'll see "Post deleted successfully"

### In Detail View:
1. **Long-press** on the post content area
2. Same confirmation dialog appears
3. After deletion, you'll be taken back to the feed

## How to Delete Comments

### Any Comment or Reply:
1. **Long-press** on any comment you wrote
2. A dialog will appear asking "Delete Comment?"
3. Tap **Delete** to confirm or **Cancel** to dismiss
4. Comment will be removed and list will refresh

## Important Notes

✅ **You can only delete your own content**
- Long-press only works on posts/comments you created
- Other users' content won't respond to long-press

✅ **Deletion is permanent**
- Once deleted, content cannot be recovered
- Always shows confirmation dialog to prevent accidents

✅ **Works everywhere**
- Space/Orbit posts and comments
- Community posts and comments
- Both feed view and detail view

## Visual Indicators

### Delete Dialog:
```
┌─────────────────────────────────┐
│  🗑️  Delete Post?               │
│                                  │
│  Are you sure you want to       │
│  delete this post? This action  │
│  cannot be undone.              │
│                                  │
│         [Cancel]  [Delete]      │
└─────────────────────────────────┘
```

### Success Message:
```
┌─────────────────────────────────┐
│  ✓ Post deleted successfully    │
└─────────────────────────────────┘
```

### Error Message (if not owner):
```
┌─────────────────────────────────┐
│  You can only delete your own   │
│  posts                          │
└─────────────────────────────────┘
```

## Gesture Guide

**Long-Press Duration**: ~500ms
- Press and hold on the post/comment
- Don't release immediately
- Wait for dialog to appear

**What Happens:**
1. User long-presses → Ownership check
2. If owner → Show delete dialog
3. If not owner → Nothing happens
4. User confirms → Delete from database
5. Success → Update UI + show message
6. Error → Show error message

## Database Tables

| Content Type | Table Name | ID Field |
|-------------|------------|----------|
| Space Posts | `posts` | `id` |
| Community Posts | `community_posts` | `id` |
| Space Comments | `comments` | `id` |
| Community Comments | `community_post_comments` | `id` |

## Code Locations

| Feature | File |
|---------|------|
| Space Post Delete | `lib/space/post_detail_screen.dart` |
| Space Post Card Delete | `lib/space/feed_post_card.dart` |
| Community Post Delete | `lib/community/community_post_detail_screen.dart` |
| Community Feed Delete | `lib/community/community_feed_screen.dart` |
