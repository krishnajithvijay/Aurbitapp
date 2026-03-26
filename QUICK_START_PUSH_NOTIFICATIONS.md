# 🔔 Push Notification Implementation - Quick Start Guide

## ✅ What's Already Done

Your app already has **most** of the push notification system in place! Here's what's already working:

### Flutter App (Client Side) ✓
- ✅ FCM packages installed (`firebase_core`, `firebase_messaging`, `flutter_local_notifications`)
- ✅ FCM Service created (`lib/services/fcm_service.dart`)
- ✅ FCM initialized in SplashScreen and LoginScreen
- ✅ Notification screen and service working
- ✅ Database triggers for auto-creating notifications (reactions, comments, replies)
- ✅ Android Manifest updated with FCM meta-data

### Database (Supabase) ✓
- ✅ `user_fcm_tokens` table created
- ✅ `notifications` table created
- ✅ Triggers for reactions, comments, replies

### Configuration ✓
- ✅ Google Services JSON uploaded
- ✅ Android gradle configured with Firebase plugin

---

## ❌ What's Missing (Need to Complete)

### 1. Firebase Service Account Key
**Status**: Need to download from Firebase Console

### 2. Supabase Edge Function
**Status**: Created locally, needs deployment

### 3. Database Trigger/Webhook
**Status**: SQL file created, needs to be run in Supabase

### 4. Message Notifications
**Status**: Service created, needs integration in chat

---

## 🚀 STEP-BY-STEP IMPLEMENTATION  

Follow these steps IN ORDER:

### STEP 1: Get Firebase Service Account Key (5 minutes)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **⚙️ Settings** → **Project Settings**
4. Go to **Service accounts** tab
5. Click **Generate new private key**
6. Download the JSON file
7. **Save it securely** - you'll need it for Step 3

### STEP 2: Install Supabase CLI (One-time, 5 minutes)

Open PowerShell/Command Prompt:

```powershell
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login
```

### STEP 3: Deploy Edge Function (10 minutes)

```powershell
# Navigate to your project
cd a:\AUR-Versions\v.3.4\aurbitapp

# Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF
# Get YOUR_PROJECT_REF from: https://supabase.com/dashboard/project/YOUR_PROJECT_REF

# Set Firebase Service Account secret
# Open the JSON file you downloaded in Step 1, copy its contents to one line
# Then run:
supabase secrets set FIREBASE_SERVICE_ACCOUNT='PASTE_JSON_HERE'

# Deploy the Edge Function
supabase functions deploy send-push-notification

# Verify deployment
supabase functions list
```

**Important**: The FIREBASE_SERVICE_ACCOUNT JSON must be on ONE LINE. Example:
```
{"type":"service_account","project_id":"aurbitapp","private_key":"-----BEGIN PRIVATE KEY-----\nMIIE..."}
```

### STEP 4: Run Database Trigger (5 minutes)

1. Open **Supabase Dashboard** → **SQL Editor**
2. Click **New query**
3. Copy and paste the contents of `push_notification_trigger.sql`
4. **IMPORTANT**: Replace these two lines:

```sql
-- Line 15: Replace with your Supabase URL
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://henxsgquexgxvfwngjet.supabase.co';

-- Line 19: Replace with your Service Role Key
-- Get from: Supabase Dashboard -> Project Settings -> API -> service_role (secret key)
ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

5. Click **Run** to execute the migration

###STEP 5: Test Push Notifications (5 minutes)

1. **Build and run the app**:
   ```powershell
   cd a:\AUR-Versions\v.3.4\aurbitapp
   flutter run
   ```

2. **Login to the app** on a physical device

3. **Check FCM token saved**:
   - In Supabase Dashboard → **SQL Editor** → Run:
   ```sql
   SELECT * FROM user_fcm_tokens ORDER BY last_updated DESC;
   ```
   - You should see your device token

4. **Send test notification**:
   - In Supabase Dashboard → **SQL Editor** → Run:
   ```sql
   -- Replace USER_ID with your actual ID
   SELECT id, username FROM profiles LIMIT 5;
   
   -- Then insert test notification
   INSERT INTO notifications (recipient_id, sender_id, type, title, body)
   VALUES (
     'YOUR_USER_ID',
     'YOUR_USER_ID',
     'reaction',
     'Test Push',
     'This is a test push notification!'
   );
   ```

5. **Check your phone** - you should receive a push notification!

6. **Check Edge Function logs**:
   - Supabase Dashboard → **Edge Functions** → `send-push-notification` → **Logs**

### STEP 6: Test Real Scenarios (10 minutes)

1. **Test Reaction**:
   - Have another user (or use another account) react to your post
   - You should get: "UserName related to your post"

2. **Test Comment**:
   - Have someone comment on your post
   - You should get: "UserName commented on your post"

3. **Test Reply**:
   - Have someone reply to your comment
   - You should get: "UserName replied to your comment"

### STEP 7: Integrate Message Notifications (Optional, 10 minutes)

If you want push notifications for messages:

1. Find your chat message sending function
2. Add this after sending a message successfully:

```dart
import '../services/message_notification_service.dart';

// After message is sent
await MessageNotificationService().createMessageNotification(
  recipientId: otherUserId,
  messagePreview: messageText,
);
```

---

## 📊 Testing Checklist

Use `test_push_notifications.sql` for comprehensive queries:

- [ ] FCM token appears in database after login
- [ ] Manual test notification sends push to device
- [ ] React to post → Push notification received
- [ ] Comment on post → Push notification received
- [ ] Reply to comment → Push notification received
- [ ] Edge Function logs show successful sends
- [ ] Tapping notification opens the app
- [ ] Background notifications work
- [ ] Foreground notifications work

---

## 🐛 Troubleshooting

### "No push notification received"

**Check 1**: FCM Token Exists
```sql
SELECT * FROM user_fcm_tokens WHERE user_id = 'YOUR_USER_ID';
```
If empty → FCM not initialized. Check console logs.

**Check 2**: Edge Function Called
```sql
SELECT * FROM net._http_response ORDER BY created DESC LIMIT 5;
```
If empty → Trigger not working. Re-run `push_notification_trigger.sql`.

**Check 3**: Edge Function Logs
- Supabase Dashboard → Edge Functions → Logs
- Look for errors

**Check 4**: Notification Created
```sql
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
```
If empty → Database triggers not working.

### "Edge Function error: FIREBASE_SERVICE_ACCOUNT not set"

**Solution**: Re-set the secret:
```powershell
supabase secrets set FIREBASE_SERVICE_ACCOUNT='YOUR_JSON'
```

### "Invalid private key" error

**Solution**: Make sure the JSON has `\n` in the private key:
```json
"private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQI..."
```

### "No tokens found for user"

**Solution**: 
1. Logout and login again
2. Grant notification permissions when prompted
3. Check `FcmService().initialize()` is called
4. Test on physical device (emulator may have issues)

---

## 💰 Cost Summary

| Service | Usage | Cost |
|---------|-------|------|
| Firebase FCM | Unlimited | **FREE** |
| Supabase Database | Included | **FREE** |
| Supabase Edge Functions | 500K/month free tier | **FREE** |
| Database Triggers (pg_net) | Unlimited | **FREE** |

**Total Cost**: **$0** (100% FREE for typical usage)

---

## 📁 Files Reference

| File | Purpose |
|------|---------|
| `FCM_IMPLEMENTATION_GUIDE.md` | Full detailed guide |
| `QUICK_START.md` | This file - quick reference |
| `lib/services/fcm_service.dart` | FCM client implementation |
| `lib/services/message_notification_service.dart` | Message notification helper |
| `supabase/functions/send-push-notification/index.ts` | Edge Function code |
| `push_notification_trigger.sql` | Database trigger to call Edge Function |
| `test_push_notifications.sql` | Testing and debugging queries |
| `android_manifest_reference.xml` | Reference for Android config |

---

## 🎯 What Gets Push Notifications?

| Action | Notification | Auto-Created? |
|--------|--------------|---------------|
| Someone reacts to your post | ✅ Yes | ✅ Automatic |
| Someone comments on your post | ✅ Yes | ✅ Automatic |
| Someone replies to your comment | ✅ Yes | ✅ Automatic |
| Someone sends orbit request | ✅ Yes | ✅ Automatic |
| Someone accepts orbit request | ✅ Yes | ✅ Automatic |
| Someone sends you a message | ✅ Yes | ⚠️ Manual (need to integrate) |

---

## ⏱️ Time Estimate

- Firebase setup: 5 minutes
- Edge Function deployment: 10 minutes
- Database trigger: 5 minutes
- Testing: 10 minutes
- **Total: ~30 minutes**

---

## 🆘 Need Help?

1. **Check console logs** - Most issues show up there
2. **Check Supabase Edge Function logs** - See what the function is receiving
3. **Use test_push_notifications.sql** - Comprehensive debugging queries
4. **Test on physical device** - Emulators can be unreliable for FCM

---

## 🎉 Success Criteria

You'll know it's working when:

1. ✅ You see "FCM Token: ..." in console logs
2. ✅ Token appears in `user_fcm_tokens` table
3. ✅ Test notification reaches your phone
4. ✅ Real notifications (reactions, comments) trigger push notifications
5. ✅ Tapping notification opens the app

---

**Good luck! 🚀**
