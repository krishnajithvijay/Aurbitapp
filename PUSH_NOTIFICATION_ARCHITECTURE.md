# 📊 Push Notification System - Complete Analysis

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER DEVICE (Flutter App)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │   User does  │───▶│   Database   │───▶│ Notification │          │
│  │   action     │    │   trigger    │    │   created    │          │
│  │ (react/etc)  │    │   fires      │    │              │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ FCM Service (fcm_service.dart)                          │       │
│  │  • Registers device token                               │       │
│  │  • Handles foreground notifications                     │       │
│  │  • Handles background notifications                     │       │
│  │  • Shows local notifications                            │       │
│  └──────────────────────────────────────────────────────────┘       │
│                                ▲                                      │
│                                │ Push Notification                   │
└────────────────────────────────┼──────────────────────────────────────┘
                                 │
┌────────────────────────────────┼──────────────────────────────────────┐
│                    FIREBASE CLOUD MESSAGING (FCM)                     │
│                 (Google's free push notification service)             │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 │ HTTP POST with OAuth2
┌────────────────────────────────┼──────────────────────────────────────┐
│                         SUPABASE EDGE FUNCTION                        │
│                     (send-push-notification/index.ts)                 │
├───────────────────────────────────────────────────────────────────────┤
│  1. Receives notification data from webhook                          │
│  2. Fetches user's FCM tokens from database                          │
│  3. Generates OAuth2 access token using Service Account              │
│  4. Sends to FCM for each device token                               │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 │ HTTP POST (webhook)
┌────────────────────────────────┼──────────────────────────────────────┐
│                      SUPABASE POSTGRESQL DATABASE                     │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────────────┐    TRIGGER    ┌──────────────────────┐         │
│  │  notifications   │───────────────▶│ trigger_push_        │         │
│  │     table        │  ON INSERT     │ notification()       │         │
│  │                  │                │                      │         │
│  │ • recipient_id   │                │ Calls Edge Function  │         │
│  │ • sender_id      │                │ via pg_net.http_post │         │
│  │ • type           │                │                      │         │
│  │ • title, body    │                └──────────────────────┘         │
│  └──────────────────┘                                                 │
│                                                                        │
│  ┌──────────────────┐                                                 │
│  │ user_fcm_tokens  │  Stores device FCM tokens                       │
│  │                  │                                                 │
│  │ • user_id        │                                                 │
│  │ • token          │                                                 │
│  │ • device_type    │                                                 │
│  └──────────────────┘                                                 │
│                                                                        │
│  AUTO-CREATE NOTIFICATIONS:                                           │
│  ┌──────────────────┐    TRIGGER    ┌──────────────────────┐         │
│  │ post_reactions   │───────────────▶│ notify_post_         │         │
│  │                  │  ON INSERT     │ reaction()           │         │
│  └──────────────────┘                └──────────────────────┘         │
│                                                                        │
│  ┌──────────────────┐    TRIGGER    ┌──────────────────────┐         │
│  │    comments      │───────────────▶│ notify_post_comment()│         │
│  │                  │  ON INSERT     │ notify_comment_reply()│         │
│  └──────────────────┘                └──────────────────────┘         │
└───────────────────────────────────────────────────────────────────────┘
```

## 📋 Current Implementation Status

### ✅ COMPLETED (Already in your app)

| Component | Status | File/Location |
|-----------|--------|---------------|
| **Flutter FCM Setup** | ✅ Done | `lib/services/fcm_service.dart` |
| **FCM Packages** | ✅ Installed | `pubspec.yaml` |
| **Firebase Initialization** | ✅ Done | `lib/main.dart` |
| **FCM Token Registration** | ✅ Done | Called in splash/login |
| **Foreground Notifications** | ✅ Done | Local notifications shown |
| **Background Notifications** | ✅ Done | Background handler implemented |
| **FCM Tokens Table** | ✅ Created | `user_fcm_tokens` (Supabase) |
| **Notifications Table** | ✅ Created | `notifications` (Supabase) |
| **Auto-notification Triggers** | ✅ Created | Reactions, comments, replies |
| **Notification UI** | ✅ Built | `notification_screen.dart` |
| **Notification Service** | ✅ Built | `notification_service.dart` |
| **Android Manifest FCM Config** | ✅ Updated | Added today |
| **Google Services JSON** | ✅ Uploaded | `android/app/google-services.json` |

### ⚠️ IN PROGRESS (Need to complete)

| Component | Status | Action Required |
|-----------|--------|-----------------|
| **Firebase Service Account** | ⚠️ Pending | Download from Firebase Console |
| **Edge Function Deployment** | ⚠️ Not Deployed | Run: `supabase functions deploy` |
| **Edge Function Secret** | ⚠️ Not Set | Run: `supabase secrets set` |
| **Database Trigger** | ⚠️ Not Created | Run `push_notification_trigger.sql` |
| **Message Notifications** | ⚠️ Not Integrated | Add to chat sending code |

### ❌ NOT STARTED (Optional enhancements)

| Feature | Priority | Description |
|---------|----------|-------------|
| Notification Tap Handling | Medium | Navigate to specific screens on tap |
| Notification Preferences | Low | Let users customize notification types |
| Notification Grouping | Low | Group multiple notifications |
| Notification Sounds | Low | Custom sounds for different types |
| Badge Count Management | Low | Update app badge with unread count |

---

## 🎯 Notification Flow Examples

### Example 1: User Reacts to Post

```
1. User A opens app, sees User B's post
2. User A taps "I Relate" button
   ↓
3. post_reactions table INSERT
   ↓
4. TRIGGER: notify_post_reaction() fires
   ↓
5. notifications table INSERT
   ├─ recipient_id: User B
   ├─ sender_id: User A
   ├─ type: 'reaction'
   ├─ title: "UserA related to your post"
   └─ post_id: <post_id>
   ↓
6. TRIGGER: trigger_push_notification() fires
   ↓
7. pg_net.http_post() calls Edge Function
   ↓
8. Edge Function (send-push-notification)
   ├─ Fetches User B's FCM tokens
   ├─ Gets OAuth2 token from Firebase
   └─ Sends to FCM API
   ↓
9. FCM delivers to User B's device(s)
   ↓
10. User B's phone shows notification
    "UserA related to your post"
```

### Example 2: Comment Reply

```
1. User A replies to User B's comment
   ↓
2. comments table INSERT (with parent_id)
   ↓
3. TRIGGER: notify_comment_reply() fires
   ↓
4. notifications table INSERT
   ↓
5. Push notification sent (same flow as above)
   ↓
6. User B receives:
   "UserA replied to your comment"
```

---

## 💾 Database Schema

### user_fcm_tokens
```sql
CREATE TABLE user_fcm_tokens (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES profiles(id),
    token TEXT NOT NULL,
    device_type TEXT, -- 'android', 'ios', 'web'
    last_updated TIMESTAMP,
    UNIQUE(user_id, token)
);
```

**Purpose**: Stores device FCM tokens for each user
**Notes**: One user can have multiple tokens (multiple devices)

### notifications
```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY,
    recipient_id UUID REFERENCES profiles(id),
    sender_id UUID REFERENCES profiles(id),
    type TEXT, -- 'reaction', 'comment', 'reply', 'orbit_request', 'message'
    post_id UUID REFERENCES posts(id),
    comment_id UUID REFERENCES comments(id),
    reaction_type TEXT,
    orbit_type TEXT,
    title TEXT NOT NULL,
    body TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP,
    UNIQUE(recipient_id, sender_id, type, post_id, comment_id)
);
```

**Purpose**: Stores all notifications (both in-app and push)
**Notes**: Unique constraint prevents duplicate notifications

---

## 🔐 Security & Permissions

### Android Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

**Status**: ✅ Already added to your manifest

### Row Level Security (RLS) Policies

#### user_fcm_tokens
- ✅ Users can view their own tokens
- ✅ Users can insert their own tokens
- ✅ Users can update their own tokens
- ✅ Users can delete their own tokens

#### notifications
- ✅ Users can view notifications sent to them
- ✅ Users can update their own notifications (mark as read)
- ✅ Authenticated users can create notifications
- ✅ Users can delete their own notifications

---

## 🧪 Testing Scenarios

### Manual Testing Checklist

1. **FCM Token Registration**
   ```
   [ ] Login to app
   [ ] Check console for "FCM Token: ..."
   [ ] Query: SELECT * FROM user_fcm_tokens
   [ ] Verify token exists
   ```

2. **Manual Push Test**
   ```
   [ ] Insert test notification in Supabase
   [ ] Check Edge Function logs
   [ ] Verify push received on device
   [ ] Verify notification shows in app
   ```

3. **Reaction Notification**
   ```
   [ ] User A reacts to User B's post
   [ ] User B receives push notification
   [ ] User B sees notification in app
   [ ] Tap notification opens post
   ```

4. **Comment Notification**
   ```
   [ ] User A comments on User B's post
   [ ] User B receives push notification
   [ ] Notification text shows comment preview
   ```

5. **Reply Notification**
   ```
   [ ] User A replies to User B's comment
   [ ] User B receives push notification
   [ ] Notification shows reply preview
   ```

6. **Background vs Foreground**
   ```
   [ ] App in background → System notification
   [ ] App in foreground → Local notification
   [ ] App closed → System notification
   ```

---

## 📊 Performance & Scalability

### Expected Load (Example: 1000 active users)

| Metric | Calculation | Result |
|--------|-------------|--------|
| Daily notifications | 1000 users × 10 notifs/user | 10,000 |
| Monthly notifications | 10,000 × 30 days | 300,000 |
| Edge Function calls | Same as notifications | 300,000 |
| Database inserts | Same as notifications | 300,000 |
| FCM API calls | 1 per device (avg 1.2) | 360,000 |

### Cost Analysis (Free Tier Limits)

| Service | Free Tier | Your Usage | Status |
|---------|-----------|------------|--------|
| Firebase FCM | Unlimited | ∞ | ✅ FREE |
| Supabase Database | 500MB | < 10MB | ✅ FREE |
| Edge Functions | 500K invocations | 300K | ✅ FREE |
| pg_net requests | Unlimited | 300K | ✅ FREE |

**Conclusion**: 100% FREE for typical usage (up to 500K notifications/month)

---

## 🚨 Known Issues & Limitations

### 1. Emulator Limitations
**Issue**: FCM may not work on emulators without Google Play Services
**Solution**: Test on physical Android device

### 2. iOS Setup
**Status**: Not configured yet
**Impact**: Push notifications won't work on iOS
**Solution**: Follow Step 1.C in FCM_IMPLEMENTATION_GUIDE.md

### 3. Notification Tap Navigation
**Status**: Basic implementation exists
**Issue**: Doesn't navigate to specific post/comment
**Solution**: Implement navigation in `fcm_service.dart` (optional)

### 4. Multiple Device Tokens
**Status**: Supported (multiple rows per user)
**Note**: Logout doesn't remove old tokens automatically
**Solution**: Call `FcmService().deleteToken()` on logout

### 5. Duplicate Notifications
**Prevention**: UNIQUE constraint in notifications table
**Effect**: Same notification won't be created twice
**Note**: If user reacts twice, notification updates timestamp

---

## 📈 Monitoring & Debugging

### Useful Queries

**Check recent notifications:**
```sql
SELECT n.*, s.username as sender, r.username as recipient
FROM notifications n
JOIN profiles s ON n.sender_id = s.id
JOIN profiles r ON n.recipient_id = r.id
ORDER BY created_at DESC LIMIT 20;
```

**Check Edge Function calls:**
```sql
SELECT * FROM net._http_response 
ORDER BY created DESC LIMIT 10;
```

**Check FCM tokens:**
```sql
SELECT p.username, f.device_type, f.last_updated
FROM user_fcm_tokens f
JOIN profiles p ON f.user_id = p.id
ORDER BY f.last_updated DESC;
```

### Logs to Monitor

1. **Flutter Console Logs**
   - Look for: "FCM Token: ..."
   - Look for: "Handling a background message: ..."

2. **Supabase Edge Function Logs**
   - Dashboard → Edge Functions → send-push-notification → Logs
   - Look for: "Push notifications sent: X success, Y failed"

3. **Supabase Database Logs**
   - Dashboard → Logs
   - Look for trigger execution logs

---

## 🎓 Key Concepts

### What is FCM?
Firebase Cloud Messaging is Google's **free** service for sending push notifications to Android, iOS, and web apps. It handles all the complexity of delivering messages to devices reliably.

### What are Edge Functions?
Serverless functions that run on Supabase's infrastructure. They're like AWS Lambda or Cloudflare Workers - you write code, upload it, and it runs on-demand when triggered.

### What is pg_net?
A PostgreSQL extension that allows the database to make HTTP requests. This lets triggers call external APIs (like our Edge Function) without extra infrastructure.

### Why not use webhooks?
We *could* use webhooks (Supabase Dashboard → Database → Webhooks), but pg_net triggers are:
- ✅ Completely free (no limits)
- ✅ Faster (runs in database)
- ✅ More reliable (retries built-in)
- ✅ No webhook quotas

---

## 🔧 Maintenance Tasks

### Regular (Weekly/Monthly)

1. **Monitor Edge Function errors**
   - Check logs for failed sends
   - Investigate and fix issues

2. **Clean up old notifications**
   ```sql
   DELETE FROM notifications 
   WHERE created_at < NOW() - INTERVAL '30 days'
   AND is_read = true;
   ```

3. **Clean up stale FCM tokens**
   ```sql
   DELETE FROM user_fcm_tokens
   WHERE last_updated < NOW() - INTERVAL '90 days';
   ```

### As Needed

1. **Update Edge Function**
   ```bash
   # After modifying index.ts
   supabase functions deploy send-push-notification
   ```

2. **Rotate Service Account Key**
   - Generate new key in Firebase Console
   - Update Supabase secret

3. **Update Firebase SDK**
   ```yaml
   # In pubspec.yaml
   firebase_core: ^LATEST
   firebase_messaging: ^LATEST
   ```

---

## 📚 Resources

### Documentation Links
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [pg_net Extension](https://github.com/supabase/pg_net)

### Your Project Files
- `FCM_IMPLEMENTATION_GUIDE.md` - Full implementation guide
- `QUICK_START_PUSH_NOTIFICATIONS.md` - Quick reference
- `test_push_notifications.sql` - Testing queries
- `push_notification_trigger.sql` - Database trigger
- `supabase/functions/send-push-notification/index.ts` - Edge Function

---

## ✅ Next Steps

1. **Download Firebase Service Account Key** (Step 1)
2. **Deploy Edge Function** (Step 3)
3. **Run Database Trigger SQL** (Step 4)
4. **Test End-to-End** (Step 5)
5. **Integrate Message Notifications** (Step 7 - Optional)

**Estimated Time**: 30 minutes total

---

**Last Updated**: 2026-01-25
**Status**: Ready for deployment
