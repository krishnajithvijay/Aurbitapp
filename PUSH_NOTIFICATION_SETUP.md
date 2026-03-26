# Push Notification Setup Guide

This guide explains how to complete the Push Notification setup for Aurbit.

## 1. Firebase Console Setup (Required)

You must set up a Firebase project and link it to your app.

### A. Create Project
1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and name it `aurbitapp`.
3. Disable Google Analytics (optional) and Create Project.

### B. Add Android App
1. In the Project Overview, click the **Android** icon.
2. Package name: `com.example.aurbitapp` (Check your `android/app/build.gradle` `applicationId` to be sure).
3. Click **Register app**.
4. Download `google-services.json`.
5. Place this file in `android/app/google-services.json`.

### C. Add iOS App (If building for iOS)
1. Add **iOS** app.
2. Bundle ID: `com.example.aurbitapp` (Check Xcode project).
3. Download `GoogleService-Info.plist`.
4. Place this file in `ios/Runner/GoogleService-Info.plist` using Xcode.

## 2. Supabase Function Setup (Backend)

We implemented the client-side logic (receiving notifications) and database logic (storing tokens). Now we need the logic to *send* the notification via FCM when a database event happens.

### A. Create Edge Function
In your Supabase project (local or cloud):

1. Create a function:
   ```bash
   supabase functions new push-notification
   ```

2. Edit `test/functions/push-notification/index.ts` (or similar path):

```typescript
// Follow Supabase Edge Function guide for FCM
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.13.1/index.ts"

console.log("Hello from Functions!")

// Service Account from Firebase Console -> Project Settings -> Service Accounts -> Generate Private Key
// Save the content as a valid JSON string in Supabase Secrets: FCM_SERVICE_ACCOUNT
const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}')

// Function to get Access Token
const getAccessToken = async () => {
  const now = Math.floor(Date.now() / 1000)
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  }

  const key = await jose.importPKCS8(serviceAccount.private_key, "RS256")
  const jwt = await new jose.SignJWT(claim).setProtectedHeader({ alg: "RS256" }).sign(key)

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  
  const data = await res.json()
  return data.access_token
}

serve(async (req) => {
  const { record } = await req.json() // The record from the 'notifications' table trigger
  
  // 1. Get User Tokens
  const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { data: tokens } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', record.recipient_id)

  if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No tokens found' }), { headers: { 'Content-Type': 'application/json' } })
  }

  // 2. Send to FCM
  const accessToken = await getAccessToken()
  const projectId = serviceAccount.project_id

  const promises = tokens.map(async (t) => {
      const message = {
          message: {
              token: t.token,
              notification: {
                  title: record.title,
                  body: record.body ?? 'New notification',
              },
              data: {
                  type: record.type,
                  postId: record.post_id ?? '',
                  commentId: record.comment_id ?? '',
              }
          }
      }

      await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json'
          },
          body: JSON.stringify(message)
      })
  })

  await Promise.all(promises)

  return new Response(
    JSON.stringify({ message: "Sent" }),
    { headers: { "Content-Type": "application/json" } },
  )
})
```

### B. Create Database Webhook
In Supabase Dashboard -> Database -> Webhooks:
1. Name: `send-push-notification`
2. Table: `notifications`
3. Event: `INSERT`
4. Type: `HTTP Request`
5. URL: `https://<your-project-ref>.supabase.co/functions/v1/push-notification` (or local URL)
6. Method: `POST`
7. Header: `Authorization: Bearer <your-anon-key>`

## 3. Deployment
1. Run the migration `fcm_migration.sql` in your Supabase SQL Editor.
2. Build and run the app.
3. Grant notification permissions on the device.
