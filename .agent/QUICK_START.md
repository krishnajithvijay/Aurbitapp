# ⚡ Quick Start Guide - Community Admin & Verification

## Step 1: Run SQL Migrations (MANDATORY)

### In Supabase SQL Editor, run these TWO files in order:

```sql
-- 1. First, run this entire file:
community_admin_features_migration.sql

-- 2. Then, run this entire file:
user_verification_migration.sql
```

**That's it for SQL!** ✅

---

## Step 2: Grant Verification to Test Users (OPTIONAL)

If you want to test the verification badges, copy this command into SQL editor:

```sql
-- Replace 'your_username' with actual username
SELECT grant_verification(
    (SELECT id FROM profiles WHERE username = 'your_username'),
    'standard'
);
```

---

## Step 3: Test in Your App

The Dart code is already created. To use it:

### A. Add Verification Badges to Usernames

```dart
import 'package:aurbitapp/widgets/verified_badge.dart';

// Wherever you show usernames:
UsernameWithBadge(
  username: user['username'],
  isVerified: user['is_verified'] ?? false,
)

// Make sure your queries include is_verified:
SELECT id, username, avatar_url, is_verified FROM profiles
```

### B. Add Members/Settings Buttons to Community Screen

```dart
import 'package:aurbitapp/community/community_members_screen.dart';
import 'package:aurbitapp/community/community_settings_screen.dart';
import 'package:aurbitapp/widgets/admin_only.dart';

// In your app bar actions:
IconButton(
  icon: Icon(Icons.people),
  onPressed: () => Navigator.push(...CommunityMembersScreen...),
),

AdminOnly(
  communityId: communityId,
  child: IconButton(
    icon: Icon(Icons.settings),
    onPressed: () => Navigator.push(...CommunitySettingsScreen...),
  ),
),
```

### C. Update Join Community Logic

```dart
import 'package:aurbitapp/widgets/ban_warning_dialog.dart';

final result = await CommunityService().joinCommunity(communityId);

if (result['success']) {
  // Joined successfully
} else if (result['banned'] == true) {
  await BanWarningDialog.show(
    context: context,
    daysRemaining: result['banInfo']['days_remaining'],
    reason: result['banInfo']['reason'],
  );
}
```

---

## What About `admin_quick_reference.sql`?

**Don't run this file!** It's just a cheat sheet of SQL commands you can copy when needed.

Use it when you want to:
- Manually grant verification to users
- Check who's banned
- Get community statistics
- Perform admin operations via SQL

---

## Testing Checklist

- [ ] Run both migration files in Supabase
- [ ] Grant verification to 1-2 test users
- [ ] Check that blue tick appears in app
- [ ] Create a test community
- [ ] Make yourself admin (you're auto-admin if you created it)
- [ ] Navigate to Community Settings (should see settings icon)
- [ ] Edit community name/bio
- [ ] Navigate to Members screen
- [ ] Add another test user to community
- [ ] Try admin actions: restrict, kick, ban
- [ ] Log in as banned user and try to rejoin (should see warning)

---

## Files Reference

### Run in Supabase SQL Editor:
- ✅ `community_admin_features_migration.sql` - **RUN THIS**
- ✅ `user_verification_migration.sql` - **RUN THIS**

### Reference/Documentation Only:
- 📚 `admin_quick_reference.sql` - Copy commands as needed
- 📚 `.agent/community_admin_verification_guide.md` - Full guide
- 📚 `.agent/implementation_summary.md` - Feature summary
- 📚 `.agent/ui_flow_guide.md` - UI/UX guide

### Example Code:
- 📝 `lib/community/example_integration.dart` - See how to integrate

---

## Need Help?

1. **Verification badge not showing?**
   - Check query includes `is_verified`
   - Verify migration ran successfully
   - Grant verification via SQL

2. **Admin features not working?**
   - Check you're actually admin in `community_members` table
   - Verify RLS policies created correctly

3. **Ban not working?**
   - Check trigger exists: `trigger_check_community_ban`
   - Verify ban_expires_at is in the future

---

**You're ready to go! 🚀**
