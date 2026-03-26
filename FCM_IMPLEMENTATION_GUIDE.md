# Complete Firebase FCM + Supabase Push Notification Implementation Guide

## 📋 Current Status Analysis

### ✅ Already Completed:
1. **Firebase packages installed** in `pubspec.yaml`:
   - `firebase_core: ^4.4.0`
   - `firebase_messaging: ^16.1.1`
   - `flutter_local_notifications: ^19.5.0`

2. **FCM Service created** (`lib/services/fcm_service.dart`):
   - Background notification handler
   - Foreground notification handler
   - FCM token management
   - Local notification display

3. **Database setup**:
   - `user_fcm_tokens` table (from `fcm_migration.sql`)
   - `notifications` table (from `notifications_migration.sql`)
   - Triggers for auto-creating notifications

4. **Notification UI**:
   - `notification_screen.dart` - displays notifications
   - `notification_service.dart` - fetches from database
   - Notification bell with unread count

5. **Google Services JSON** uploaded to `android/app/google-services.json`

6. **Android gradle** configured with `com.google.gms.google-services` plugin

7. **FCM initialization** called in `splash_screen.dart` and `login_screen.dart`

### ❌ Missing Components:
1. **Supabase Edge Function** - to send push notifications when database notifications are created
2. **Database webhook/trigger** - to invoke the Edge Function
3. **Firebase Service Account** - needs to be added to Supabase secrets
4. **Android Manifest permissions** - notification permissions
5. **Message handling** - needs to integrate messages with push notifications
6. **Testing** - end-to-end push notification flow

---

## 🚀 Complete Implementation Steps

## STEP 1: Verify Firebase Setup

### 1.1 Confirm Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Verify your project exists or create new project
3. **Important**: Note your **Project ID** (e.g., `aurbitapp-12345`)

### 1.2 Verify Android App Configuration
1. In Firebase Console → **Project Settings**
2. Under **Your apps** → Android app
3. Verify Package name: `com.example.aurbitapp` (matches your `android/app/build.gradle.kts`)
4. Confirm `google-services.json` is downloaded and placed in `android/app/`

### 1.3 Get Firebase Service Account Key (FOR SUPABASE)
1. In Firebase Console → **Project Settings** → **Service accounts**
2. Click **Generate new private key**
3. Download the JSON file (e.g., `aurbitapp-firebase-adminsdk.json`)
4. **Keep this file secure** - you'll need it for Supabase

---

## STEP 2: Android Manifest Configuration

### 2.1 Update AndroidManifest.xml

**File**: `android/app/src/main/AndroidManifest.xml`

Add these permissions and configurations:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Add permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>

    <application
        android:label="aurbitapp"
        android:name="${applicationName}"
        android:icon="@mipmap/launcher_icon">
        
        <!-- Existing activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:showWhenLocked="true"
            android:turnScreenOn="true">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"
                />
                
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- FCM Default Notification Channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
            
        <!-- FCM Default Notification Icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/launcher_icon" />
            
        <!-- FCM Default Notification Color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@android:color/white" />

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

---

## STEP 3: Run Database Migrations

### 3.1 Run FCM Token Migration

Go to **Supabase Dashboard** → **SQL Editor** → New Query

Run the migration:

```sql
-- This file: fcm_migration.sql (already exists)
```

**Run command**: Execute `fcm_migration.sql` in Supabase SQL Editor

### 3.2 Verify Tables Created

Run this query to verify:

```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_fcm_tokens', 'notifications');

-- Check FCM tokens table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_fcm_tokens';
```

---

## STEP 4: Create Supabase Edge Function

### 4.1 Install Supabase CLI (if not installed)

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login
```

### 4.2 Link Your Supabase Project

```bash
# In your project directory
cd a:\AUR-Versions\v.3.4\aurbitapp

# Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF
# Get YOUR_PROJECT_REF from Supabase Dashboard URL
```

### 4.3 Create Edge Function

```bash
# Create the edge function
supabase functions new send-push-notification
```

### 4.4 Write Edge Function Code

**File**: `supabase/functions/send-push-notification/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.13.1/index.ts"

console.log("Push Notification Function Started")

// Get Firebase Service Account from environment
const getServiceAccount = () => {
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!serviceAccountJson) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable not set')
  }
  return JSON.parse(serviceAccountJson)
}

// Generate OAuth2 Access Token for FCM
const getAccessToken = async (serviceAccount: any) => {
  const now = Math.floor(Date.now() / 1000)
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  }

  const key = await jose.importPKCS8(serviceAccount.private_key, "RS256")
  const jwt = await new jose.SignJWT(claim)
    .setProtectedHeader({ alg: "RS256" })
    .sign(key)

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const data = await response.json()
  return data.access_token
}

serve(async (req) => {
  try {
    // Parse webhook payload
    const payload = await req.json()
    console.log("Received payload:", JSON.stringify(payload))

    const record = payload.record || payload

    // Validate required fields
    if (!record.recipient_id) {
      return new Response(
        JSON.stringify({ error: 'recipient_id is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get recipient's FCM tokens
    const { data: tokens, error: tokensError } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', record.recipient_id)

    if (tokensError) {
      console.error('Error fetching tokens:', tokensError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch tokens', details: tokensError }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (!tokens || tokens.length === 0) {
      console.log('No FCM tokens found for user:', record.recipient_id)
      return new Response(
        JSON.stringify({ message: 'No tokens found for user' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Found ${tokens.length} token(s) for user`)

    // Get Firebase service account and access token
    const serviceAccount = getServiceAccount()
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id

    // Send notification to each device token
    const results = await Promise.allSettled(
      tokens.map(async (tokenData) => {
        const message = {
          message: {
            token: tokenData.token,
            notification: {
              title: record.title || 'New Notification',
              body: record.body || 'You have a new notification',
            },
            data: {
              type: record.type || 'general',
              post_id: record.post_id || '',
              comment_id: record.comment_id || '',
              notification_id: record.id || '',
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'high_importance_channel',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          },
        }

        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(message),
          }
        )

        if (!response.ok) {
          const errorData = await response.json()
          console.error('FCM send error:', errorData)
          throw new Error(`FCM send failed: ${JSON.stringify(errorData)}`)
        }

        return await response.json()
      })
    )

    const successCount = results.filter(r => r.status === 'fulfilled').length
    const failureCount = results.filter(r => r.status === 'rejected').length

    console.log(`Push notifications sent: ${successCount} success, ${failureCount} failed`)

    return new Response(
      JSON.stringify({
        message: 'Push notifications processed',
        success: successCount,
        failed: failureCount,
        results: results.map(r => r.status === 'fulfilled' ? 'sent' : 'failed'),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## STEP 5: Set Supabase Secrets

### 5.1 Prepare Firebase Service Account JSON

Take the Firebase Service Account JSON file you downloaded and **minify it to a single line**.

**Example**:
```json
{"type":"service_account","project_id":"aurbitapp-12345","private_key_id":"abc123","private_key":"-----BEGIN PRIVATE KEY-----\nMIIE...","client_email":"firebase-adminsdk-...@aurbitapp-12345.iam.gserviceaccount.com","client_id":"123456","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-..."}
```

### 5.2 Set Secret in Supabase

```bash
# Set the Firebase service account as a secret
supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
```

**Alternative**: Use Supabase Dashboard:
1. Go to **Project Settings** → **Edge Functions** → **Secrets**
2. Add secret: `FIREBASE_SERVICE_ACCOUNT`
3. Paste the minified JSON

---

## STEP 6: Deploy Edge Function

### 6.1 Deploy to Supabase

```bash
# Deploy the edge function
supabase functions deploy send-push-notification
```

### 6.2 Verify Deployment

```bash
# List all functions
supabase functions list

# Test the function (optional)
supabase functions serve send-push-notification
```

---

## STEP 7: Create Database Webhook/Trigger

### Option A: Database Trigger (Recommended - FREE)

**File**: `push_notification_trigger.sql`

```sql
-- Function to call Supabase Edge Function
CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    function_url TEXT;
    request_id BIGINT;
BEGIN
    -- Get the Supabase URL
    function_url := current_setting('app.settings.supabase_url', true) 
                    || '/functions/v1/send-push-notification';
    
    -- Use pg_net to make async HTTP request
    SELECT net.http_post(
        url := function_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := jsonb_build_object('record', row_to_json(NEW))
    ) INTO request_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on notifications table
DROP TRIGGER IF EXISTS on_notification_created ON notifications;
CREATE TRIGGER on_notification_created
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_push_notification();
```

**IMPORTANT**: This requires `pg_net` extension. Enable it:

```sql
-- Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Set runtime settings (replace with your actual values)
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

### Option B: Supabase Dashboard Webhook

1. Go to **Supabase Dashboard** → **Database** → **Webhooks**
2. Click **Create a new webhook**
3. Configure:
   - **Name**: `push-notification-webhook`
   - **Table**: `notifications`
   - **Events**: `INSERT`
   - **Type**: `HTTP Request`
   - **Method**: `POST`
   - **URL**: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification`
   - **HTTP Headers**:
     ```
     Authorization: Bearer YOUR_ANON_KEY
     Content-Type: application/json
     ```
4. Click **Create webhook**

---

## STEP 8: Flutter App Updates

### 8.1 Verify FCM Initialization in main.dart

Your `main.dart` already initializes Firebase, but let's make sure FCM is initialized after login:

**File**: `lib/main.dart` (already has `Firebase.initializeApp()` ✅)

### 8.2 Update Splash Screen to Initialize FCM

**File**: `lib/authentication/splash_screen.dart`

The code already calls `FcmService().initialize()` ✅

### 8.3 Add Message Notifications

Create a service to handle new messages with push notifications:

**File**: `lib/services/message_notification_service.dart` (NEW)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class MessageNotificationService {
  final _supabase = Supabase.instance.client;

  // Create notification when message is sent
  Future<void> createMessageNotification({
    required String recipientId,
    required String messagePreview,
    String? chatId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .single();

      await _supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': userId,
        'type': 'message',
        'title': '${profile['username']} sent you a message',
        'body': messagePreview,
      });
    } catch (e) {
      debugPrint('Error creating message notification: $e');
    }
  }
}
```

### 8.4 Integrate Message Notifications in Chat

Find your chat/messaging service and add notification creation when sending messages.

**Example integration** (find your chat sending function):

```dart
// After sending a message successfully
await MessageNotificationService().createMessageNotification(
  recipientId: otherUserId,
  messagePreview: messageText.length > 50 
    ? '${messageText.substring(0, 50)}...' 
    : messageText,
);
```

---

## STEP 9: Handle Notification Taps

### 9.1 Update FCM Service to Handle Taps

**File**: `lib/services/fcm_service.dart`

Add this method to handle notification taps:

```dart
// Add this import at top
import 'package:flutter/material.dart';

// Add this to FcmService class
void setupNotificationInteraction(BuildContext context) {
  // Handle notification tap when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(context, message);
  });

  // Check if app was opened from a notification
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      _handleNotificationTap(context, message);
    }
  });
}

void _handleNotificationTap(BuildContext context, RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  
  // Navigate based on notification type
  if (type == 'comment' || type == 'reply' || type == 'reaction') {
    // Navigate to post detail
    // You'll need to import your PostDetailScreen
    // Navigator.push(context, MaterialPageRoute(...));
  } else if (type == 'message') {
    // Navigate to chat/message screen
  } else if (type == 'orbit_request' || type == 'orbit_accept') {
    // Navigate to notification screen
  }
}
```

---

## STEP 10: Testing

### 10.1 Test FCM Token Registration

1. Run your app on a physical device (or emulator with Google Play Services)
2. Login to the app
3. Check console logs for: `FCM Token: ...`
4. Verify token in Supabase:

```sql
SELECT * FROM user_fcm_tokens ORDER BY last_updated DESC LIMIT 10;
```

### 10.2 Test Push Notification End-to-End

1. **Create a test notification manually**:

```sql
-- Replace USER_ID with actual user ID
INSERT INTO notifications (recipient_id, sender_id, type, title, body)
VALUES (
  'USER_ID_HERE',  -- recipient
  'USER_ID_HERE',  -- sender (can be same for testing)
  'reaction',
  'Test Notification',
  'This is a test push notification'
);
```

2. **Check Edge Function logs**:
   - Go to Supabase Dashboard → Edge Functions → `send-push-notification` → Logs
   - Look for execution logs and errors

3. **Verify notification received on device**

### 10.3 Test Real Scenarios

1. **Test Reaction Notification**:
   - User A reacts to User B's post
   - User B should receive push notification

2. **Test Comment Notification**:
   - User A comments on User B's post
   - User B should receive push notification

3. **Test Reply Notification**:
   - User A replies to User B's comment
   - User B should receive push notification

4. **Test Message Notification**:
   - User A sends message to User B
   - User B should receive push notification

---

## STEP 11: Troubleshooting

### Issue: No FCM token in database
**Solution**:
- Check if `FcmService().initialize()` is called after login
- Verify notification permissions are granted
- Check console logs for errors
- Test on physical device (emulators may have issues)

### Issue: Edge Function not triggered
**Solution**:
- Verify webhook is created correctly
- Check Edge Function deployment: `supabase functions list`
- Check Edge Function logs for errors
- Verify `FIREBASE_SERVICE_ACCOUNT` secret is set

### Issue: Push notification not received
**Solution**:
- Verify FCM token exists in database
- Check Edge Function logs
- Verify Firebase Service Account has correct permissions
- Check if notification channel is created (Android)
- Test with a simple manual notification insert

### Issue: "Invalid private key" error
**Solution**:
- Ensure private key in service account JSON has `\n` characters
- The key should start with `-----BEGIN PRIVATE KEY-----\n`
- Don't escape backslashes when setting the secret

---

## 📱 Summary of What Gets Pushed

| Event | Notification Type | Push Notification? |
|-------|------------------|-------------------|
| Someone reacts to your post | `reaction` | ✅ YES |
| Someone comments on your post | `comment` | ✅ YES |
| Someone replies to your comment | `reply` | ✅ YES |
| Someone sends orbit request | `orbit_request` | ✅ YES |
| Someone accepts orbit request | `orbit_accept` | ✅ YES |
| Someone sends you a message | `message` | ✅ YES |

---

## 💰 Cost Analysis (FREE Tier)

### Firebase FCM: **100% FREE**
- Unlimited push notifications
- No cost for any tier

### Supabase:
- **Database**: Free tier includes PostgreSQL
- **Edge Functions**: Free tier includes 500K invocations/month
- **Database Triggers**: FREE (no limit)

### Estimated Usage:
- If you have 1000 active users
- Average 10 notifications/user/day
- = 10,000 notifications/day
- = 300,000 notifications/month
- **Cost: $0** (well within free tier)

---

## 🎯 Next Steps

1. ✅ Complete Steps 1-10 above
2. Test thoroughly on multiple devices
3. Monitor Edge Function performance in Supabase Dashboard
4. Set up error logging and monitoring
5. Consider adding notification preferences for users
6. Implement notification sound customization
7. Add notification grouping/batching for heavy users

---

## 📚 Additional Resources

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [Supabase Database Webhooks](https://supabase.com/docs/guides/database/webhooks)
