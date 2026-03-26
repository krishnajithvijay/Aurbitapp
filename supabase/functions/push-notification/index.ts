// Follow Supabase Edge Function guide for FCM
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.13.1/index.ts"

console.log("Hello from Functions! (Version 4 - Stable)")

const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}')

const getAccessToken = async () => {
  try {
    const now = Math.floor(Date.now() / 1000)
    const claim = {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    }

    // SANITIZATION STRATEGY:
    // 1. Get the raw string
    let rawKey = serviceAccount.private_key;
    
    // 2. Replace literal "\n" (two chars) with actual newline character
    // This is the most common issue with JSON-stored keys
    if (rawKey && rawKey.includes('\\n')) {
        rawKey = rawKey.replace(/\\n/g, '\n');
    }

    // 3. Import using jose
    // jose.importPKCS8 expects the PEM string with headers
    const key = await jose.importPKCS8(rawKey, "RS256")
    
    const jwt = await new jose.SignJWT(claim).setProtectedHeader({ alg: "RS256" }).sign(key)

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    })
    
    if (!res.ok) {
       const text = await res.text()
       console.error("Failed to get google access token. response:", text)
       throw new Error(`Google Auth Failed: ${res.status} ${res.statusText}`)
    }

    const data = await res.json()
    return data.access_token
  } catch (e) {
    console.error("Error in getAccessToken:", e)
    throw e;
  }
}

serve(async (req) => {
  try {
      const { record } = await req.json()
      
      // 1. Setup Supabase Client
      const supabase = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // 2. Fetch Tokens
      // We use the service_role key, so RLS is bypassed automatically.
      const { data: tokens, error } = await supabase
          .from('user_fcm_tokens')
          .select('token')
          .eq('user_id', record.recipient_id)

      if (error) {
          console.error("DB Error:", error)
          return new Response(JSON.stringify({ error: error.message }), { status: 500 })
      }

      if (!tokens || tokens.length === 0) {
          console.log(`No tokens found for recipient ${record.recipient_id}. Skipping FCM.`)
          return new Response(JSON.stringify({ message: 'No tokens found' }), {
            headers: { 'Content-Type': 'application/json' } 
          })
      }
      
      console.log(`Found ${tokens.length} tokens. Authenticating with Google...`)

      // 3. Authenticate
      const accessToken = await getAccessToken()
      const projectId = serviceAccount.project_id
      
      console.log("Authenticated. Sending messages...")

      // 4. Send Messages
      const promises = tokens.map(async (t) => {
          const message = {
              message: {
                  token: t.token,
                  notification: {
                      title: record.title,
                      body: record.body,
                  },
                  data: {
                      // Ensure all values are strings for FCM data payload
                      type: String(record.type || ''),
                      postId: String(record.post_id || ''),
                      commentId: String(record.comment_id || ''),
                      click_action: 'FLUTTER_NOTIFICATION_CLICK' 
                  }
              }
          }

          const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
              method: 'POST',
              headers: {
                  'Authorization': `Bearer ${accessToken}`,
                  'Content-Type': 'application/json'
              },
              body: JSON.stringify(message)
          })
          
          if (!res.ok) {
            const errText = await res.text()
            console.error(`FCM Send Failed for token ${t.token.substring(0, 10)}...:`, errText)
            return { error: errText }
          }
          
          const result = await res.json()
          return result
      })

      const results = await Promise.all(promises)
      console.log("Sent batch. Results:", JSON.stringify(results))

      return new Response(
        JSON.stringify({ results }),
        { headers: { "Content-Type": "application/json" } },
      )
  } catch(e) {
      console.error("Critical error in function:", e)
      return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
