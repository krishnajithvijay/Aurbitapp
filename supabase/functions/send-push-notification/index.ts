import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.13.1/index.ts"

console.log("Push Notification Function Started")

// Helper to safely parse the service account JSON
const getServiceAccount = () => {
  let rawSecret = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || ''
  
  if (!rawSecret) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable not set')
  }

  // DEBUG LOG: Print first 10 and last 10 chars to debug
  console.log(`Raw secret start: [${rawSecret.substring(0, 10)}] end: [${rawSecret.substring(rawSecret.length - 10)}]`)

  // Aggressive Cleaning: Find the JSON object inside the string
  const firstBrace = rawSecret.indexOf('{')
  const lastBrace = rawSecret.lastIndexOf('}')

  if (firstBrace === -1 || lastBrace === -1) {
    throw new Error("Invalid Secret: Could not find JSON object { ... } boundaries")
  }

  const cleanJson = rawSecret.substring(firstBrace, lastBrace + 1)

  try {
    return JSON.parse(cleanJson)
  } catch (e) {
    console.error("Still failed to parse. Cleaned content preview:", cleanJson.substring(0, 50))
    throw new Error(`JSON Parse Error: ${e.message}`)
  }
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

  // KEY FIX: Handle both literal "\n" strings and actual newlines
  let privateKey = serviceAccount.private_key
  if (typeof privateKey === 'string') {
      // Replace literal "\n" characters with actual newlines if needed
      privateKey = privateKey.replace(/\\n/g, '\n');
  }

  const key = await jose.importPKCS8(privateKey, "RS256")
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
    const payload = await req.json()
    console.log("Received payload:", JSON.stringify(payload))

    const record = payload.record || payload

    // 1. Determine Target User (Handle both 'recipient_id' for notifications and 'receiver_id' for messages)
    const targetUserId = record.recipient_id || record.receiver_id;

    if (!targetUserId) {
      return new Response(JSON.stringify({ error: 'recipient_id or receiver_id is required' }), { status: 400 })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 2. Prepare Notification Content
    let notificationTitle = record.title || 'New Notification';
    let notificationBody = record.body || 'You have a new notification';
    let notificationType = record.type || 'general';

    // Special Handling for Chat Messages (have sender_id and content)
    if (record.sender_id && record.content) {
       // Fetch sender's username
       const { data: senderData } = await supabase
        .from('profiles')
        .select('username')
        .eq('id', record.sender_id)
        .single();
    
       const senderName = senderData?.username || 'Someone';
       notificationTitle = `New message from ${senderName}`;
       notificationBody = record.content;
       notificationType = 'chat';
    }

    // 3. Fetch FCM token ONLY from profiles table as requested
    let finalTokens: string[] = [];
    
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', targetUserId)
      .single()
    
    if (profileData && profileData.fcm_token) {
      console.log('Found token in profiles table');
      finalTokens = [profileData.fcm_token];
    }

    if (finalTokens.length === 0) {
      console.log('No FCM tokens found for user:', targetUserId)
      return new Response(JSON.stringify({ message: 'No tokens found for user' }), { status: 200 })
    }

    console.log(`Found ${finalTokens.length} token(s) for user`)

    const serviceAccount = getServiceAccount()
    const accessToken = await getAccessToken(serviceAccount)
    const projectId = serviceAccount.project_id

    const results = await Promise.allSettled(
      finalTokens.map(async (fcmToken: string) => {
        const message = {
          message: {
            token: fcmToken,
            notification: {
              title: notificationTitle,
              body: notificationBody,
            },
            data: {
              type: notificationType,
              post_id: record.post_id || '',
              community_post_id: record.community_post_id || '',
              comment_id: record.comment_id || '',
              notification_id: record.id || '',
              sender_id: record.sender_id || '', // Include sender_id for chat navigation
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'high_importance_channel',
              }
            }
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

    return new Response(
      JSON.stringify({
        message: 'Push notifications processed',
        success: results.filter(r => r.status === 'fulfilled').length,
        failed: results.filter(r => r.status === 'rejected').length
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
