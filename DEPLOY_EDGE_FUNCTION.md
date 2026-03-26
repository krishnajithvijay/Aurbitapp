# 🚀 Deploy Edge Function - Step by Step

Follow these commands **in order**. Copy and paste each command.

---

## STEP 1: Install Supabase CLI (If Not Already Installed)

Open PowerShell or Command Prompt and run:

```powershell
npm install -g supabase
```

**Wait for it to complete**, then verify:

```powershell
supabase --version
```

You should see something like: `1.x.x` or `2.x.x`

---

## STEP 2: Login to Supabase

```powershell
supabase login
```

This will:
1. Open your browser
2. Ask you to authorize the CLI
3. Return to terminal when done

**Wait for**: "Finished supabase login"

---

## STEP 3: Navigate to Your Project

```powershell
cd a:\AUR-Versions\v.3.4\aurbitapp
```

---

## STEP 4: Link Your Supabase Project

```powershell
supabase link --project-ref henxsgquexgxvfwngjet
```

**Wait for**: "Finished supabase link"

---

## STEP 5: Get Firebase Service Account JSON

### A. Download from Firebase Console

1. Go to: https://console.firebase.google.com/
2. Select your project
3. Click ⚙️ (Settings) → **Project Settings**
4. Go to **Service accounts** tab
5. Click **Generate new private key**
6. Click **Generate key** (downloads JSON file)

### B. Minify the JSON

**Option 1: Online Tool**
- Go to: https://codebeautify.org/jsonminifier
- Paste your JSON content
- Click "Minify"
- Copy the result

**Option 2: Manual**
- Open the downloaded JSON file
- Copy all contents
- Remove ALL line breaks (make it one single line)

**Example of minified JSON:**
```json
{"type":"service_account","project_id":"yourproject","private_key_id":"abc123","private_key":"-----BEGIN PRIVATE KEY-----\nMIIE...","client_email":"firebase-adminsdk-...@yourproject.iam.gserviceaccount.com","client_id":"123","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-..."}
```

---

## STEP 6: Set Firebase Service Account Secret

Replace `PASTE_YOUR_MINIFIED_JSON_HERE` with your actual minified JSON:

```powershell
supabase secrets set FIREBASE_SERVICE_ACCOUNT='PASTE_YOUR_MINIFIED_JSON_HERE'
```

**IMPORTANT:**
- The JSON must be in **single quotes**: `'...'`
- The JSON must be **one line** (no line breaks)
- Include the `\n` in the private key (they're important!)

**Example:**
```powershell
supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"aurbitapp","private_key":"-----BEGIN PRIVATE KEY-----\nMIIE...","client_email":"..."}'
```

**Wait for**: "Finished supabase secrets set"

---

## STEP 7: Verify Secret Was Set

```powershell
supabase secrets list
```

You should see:
```
FIREBASE_SERVICE_ACCOUNT
```

---

## STEP 8: Deploy the Edge Function

```powershell
supabase functions deploy send-push-notification
```

**Wait for**: "Deployed Function send-push-notification"

This takes about 30-60 seconds.

---

## STEP 9: Verify Deployment

```powershell
supabase functions list
```

You should see:
```
send-push-notification
```

---

## ✅ SUCCESS! Edge Function is Deployed

Your Edge Function is now live at:
```
https://henxsgquexgxvfwngjet.supabase.co/functions/v1/send-push-notification
```

---

## 🧪 Quick Test (Optional)

Test the Edge Function directly:

```powershell
curl -X POST https://henxsgquexgxvfwngjet.supabase.co/functions/v1/send-push-notification -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlbnhzZ3F1ZXhneHZmd25namV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjg4NTIsImV4cCI6MjA4NDUwNDg1Mn0.qhovSln6868wGsK-7jqM9D-C2133_Gcpj-E1uX4QHg0" -H "Content-Type: application/json" -d "{\"record\":{\"recipient_id\":\"test\",\"title\":\"Test\",\"body\":\"Test\"}}"
```

Expected response: `{"message":"No tokens found for user"}`
(This is fine - it means the function works!)

---

## 🐛 Troubleshooting

### "command not found: supabase"
**Solution**: Node.js not installed or npm not in PATH
- Install Node.js from: https://nodejs.org/
- Then run: `npm install -g supabase`

### "Failed to link project"
**Solution**: Wrong project ref
- Check your Supabase dashboard URL
- It should be: `https://supabase.com/dashboard/project/henxsgquexgxvfwngjet`
- Use the part after `/project/`

### "Invalid JSON" when setting secret
**Solution**: JSON not properly formatted
- Make sure it's ONE LINE
- Use SINGLE quotes around the JSON
- Don't escape the `\n` characters in private_key
- Example: `'{"private_key":"-----BEGIN PRIVATE KEY-----\nMIIE..."}'`

### "Function deploy failed"
**Solution**: Check the error message
- Run: `supabase functions logs send-push-notification`
- Fix the issue mentioned
- Re-deploy: `supabase functions deploy send-push-notification`

---

## 📋 All Commands Summary

```powershell
# 1. Install
npm install -g supabase

# 2. Login
supabase login

# 3. Navigate
cd a:\AUR-Versions\v.3.4\aurbitapp

# 4. Link
supabase link --project-ref henxsgquexgxvfwngjet

# 5. Set secret (replace with your JSON)
supabase secrets set FIREBASE_SERVICE_ACCOUNT='YOUR_MINIFIED_JSON_HERE'

# 6. Deploy
supabase functions deploy send-push-notification

# 7. Verify
supabase functions list
```

---

## ⏭️ What's Next?

After successful deployment:

1. ✅ Edge Function deployed
2. ⏭️ Setup database trigger (5 min)
3. ⏭️ Test push notifications (5 min)

**Go to**: `TRIGGER_METHODS_COMPARISON.md` for next steps

---

## 🎯 Time Spent

- Step 1-4: ~3 minutes
- Step 5 (Firebase): ~5 minutes
- Step 6-9 (Deploy): ~2 minutes

**Total: ~10 minutes** ✅

---

**Ready to deploy? Start with Step 1!** 🚀
