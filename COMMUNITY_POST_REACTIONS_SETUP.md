# Community Post Reactions Setup Guide

## Problem
The app was trying to insert community post reactions into the `post_reactions` table, which references the `posts` table. This caused a foreign key constraint error because community posts are stored in the `community_posts` table, not the `posts` table.

**Error:**
```
PostgrestException(message: insert or update on table "post_reactions" violates foreign key constraint "post_reactions_post_id_fkey", code: 23503, details: Key is not present in table "posts"., hint: null)
```

## Solution
Created a separate `community_post_reactions` table that properly references `community_posts` instead of `posts`.

---

## Files Created/Modified

### 1. **New Migration File** ✅
**File:** `community_post_reactions_migration.sql`

This migration creates:
- `community_post_reactions` table with proper foreign keys to `community_posts`
- Row Level Security (RLS) policies ensuring only community members can react
- Helper functions:
  - `get_community_post_reaction_counts()` - Get reaction counts
  - `get_user_community_post_reaction()` - Check user's reaction
  - `toggle_community_post_reaction()` - Toggle reactions

### 2. **Updated Flutter Code** ✅
**File:** `lib/community/community_post_detail_screen.dart`

Changed all references from `post_reactions` to `community_post_reactions`:
- Line 51: Fetching "I relate" count
- Line 57: Fetching "You're not alone" count
- Line 67: Fetching user's reactions
- Line 131: Deleting reactions
- Line 138: Deleting opposite reaction when switching
- Line 145: Inserting new reactions

---

## Next Steps

### Step 1: Run the SQL Migration
1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy the entire contents of `community_post_reactions_migration.sql`
4. Paste and **Run** the migration
5. Verify the table was created successfully

### Step 2: Test the Application
1. **Hot restart** your Flutter app (not just hot reload)
2. Navigate to a community post
3. Try clicking the reaction buttons ("I relate" or "You're not alone")
4. Verify that:
   - Reactions are saved successfully
   - Counts update correctly
   - You can toggle reactions on/off
   - You can switch between reaction types

### Step 3: Verify Database
After testing, check your Supabase dashboard:
1. Go to **Table Editor**
2. Find the `community_post_reactions` table
3. Verify that reactions are being stored correctly

---

## Database Schema

### community_post_reactions Table
```sql
Column           | Type      | Description
-----------------|-----------|------------------------------------------
id               | UUID      | Primary key
post_id          | UUID      | References community_posts(id)
user_id          | UUID      | References profiles(id)
reaction_type    | TEXT      | 'i_relate' or 'youre_not_alone'
created_at       | TIMESTAMP | When the reaction was created
```

**Constraints:**
- Unique constraint on (post_id, user_id) - one reaction per user per post
- Check constraint on reaction_type - only allows valid values

**Security:**
- Users can only react if they are members of the community
- Users can only update/delete their own reactions
- Everyone can view reactions

---

## Architecture Notes

### Separation of Concerns
- **Space Posts** → `posts` table → `post_reactions` table
- **Community Posts** → `community_posts` table → `community_post_reactions` table

This separation ensures:
1. Proper foreign key relationships
2. Different access control rules (community membership required)
3. Cleaner data model
4. Easier to maintain and scale

### Reaction Types
Both tables use the same reaction types:
- `'i_relate'` - User relates to the post
- `'youre_not_alone'` - User wants to show support

---

## Troubleshooting

### Issue: Still getting foreign key error
**Solution:** Make sure you've:
1. Run the SQL migration in Supabase
2. Hot restarted the Flutter app (not just hot reload)
3. Cleared any cached data

### Issue: "Permission denied" error
**Solution:** The RLS policies require community membership. Ensure:
1. The user is a member of the community
2. The `community_members` table has the correct entry

### Issue: Reactions not showing up
**Solution:** 
1. Check the Supabase logs for errors
2. Verify the post_id exists in `community_posts` table
3. Ensure the user is authenticated

---

## Testing Checklist

- [ ] SQL migration runs without errors
- [ ] Can add "I relate" reaction
- [ ] Can add "You're not alone" reaction
- [ ] Can toggle reaction off (click same button twice)
- [ ] Can switch between reaction types
- [ ] Reaction counts update in real-time
- [ ] Reactions persist after app restart
- [ ] Only community members can react
- [ ] Non-members see reactions but can't add them

---

## Related Files

- `post_reactions_migration.sql` - Original reactions for space posts
- `community_post_comments_migration.sql` - Comments for community posts
- `lib/space/post_detail_screen.dart` - Uses `post_reactions` for space posts
- `lib/community/community_feed_screen.dart` - Displays community posts (no interaction)

---

## Future Enhancements

Consider adding:
1. Real-time reaction updates using Supabase subscriptions
2. Reaction animations in the UI
3. Notification when someone reacts to your post
4. Analytics on most popular reaction types
5. Additional reaction types if needed
