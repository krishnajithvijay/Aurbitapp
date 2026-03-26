# 🚀 Push Notification Deployment Commands
# Copy and paste these commands in order

# ============================================
# PREREQUISITES CHECK
# ============================================

# 1. Check if Node.js is installed (required for Supabase CLI)
node --version
# Should show: v18.x.x or higher

# If not installed, download from: https://nodejs.org/

# ============================================
# STEP 1: INSTALL SUPABASE CLI
# ============================================

# Install globally
npm install -g supabase

# Verify installation
supabase --version

# ============================================
# STEP 2: LOGIN TO SUPABASE
# ============================================

# This will open your browser for authentication
supabase login

# ============================================
# STEP 3: LINK YOUR PROJECT
# ============================================

# Navigate to your project directory
cd a:\AUR-Versions\v.3.4\aurbitapp

# Link to your Supabase project
# Get YOUR_PROJECT_REF from: https://supabase.com/dashboard/project/YOUR_PROJECT_REF
# It's in the URL when you're in your Supabase dashboard
supabase link --project-ref YOUR_PROJECT_REF

# ============================================
# STEP 4: SET FIREBASE SERVICE ACCOUNT SECRET
# ============================================

# First, download the Firebase Service Account JSON:
# 1. Go to: https://console.firebase.google.com/
# 2. Select your project
# 3. Settings → Project Settings → Service Accounts
# 4. Click "Generate new private key"
# 5. Download the JSON file

# Minify the JSON to one line (remove all newlines)
# You can use: https://codebeautify.org/jsonminifier
# Or just copy the contents and remove line breaks manually

# Then set it as a Supabase secret:
supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"YOUR_PROJECT_ID",...}'

# IMPORTANT: The entire JSON must be in single quotes with NO line breaks

# To verify secret was set:
supabase secrets list

# ============================================
# STEP 5: DEPLOY EDGE FUNCTION
# ============================================

# Deploy the push notification function
supabase functions deploy send-push-notification

# Verify deployment
supabase functions list

# Check function logs (optional)
supabase functions logs send-push-notification

# ============================================
# STEP 6: RUN DATABASE MIGRATIONS
# ============================================

# Option A: Run via Supabase CLI (if you have local migrations)
supabase db push

# Option B: Run manually in Supabase Dashboard (RECOMMENDED)
# 1. Go to: https://supabase.com/dashboard/project/YOUR_PROJECT_REF/sql
# 2. Copy contents of: push_notification_trigger.sql
# 3. IMPORTANT: Replace these two lines:
#    Line 15: ALTER DATABASE postgres SET app.settings.supabase_url = 'YOUR_ACTUAL_URL';
#    Line 19: ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
# 4. Click "Run"

# Get your Service Role Key from:
# https://supabase.com/dashboard/project/YOUR_PROJECT_REF/settings/api
# Look for "service_role" under "Project API keys" (it's the secret one)

# ============================================
# STEP 7: VERIFY SETUP
# ============================================

# Check if pg_net extension is enabled
# Run in Supabase SQL Editor:
# SELECT * FROM pg_extension WHERE extname = 'pg_net';

# Check if trigger is created
# Run in Supabase SQL Editor:
# SELECT * FROM information_schema.triggers WHERE trigger_name = 'on_notification_created';

# ============================================
# STEP 8: TEST END-TO-END
# ============================================

# Run the Flutter app
cd a:\AUR-Versions\v.3.4\aurbitapp
flutter pub get
flutter run

# After app is running and you're logged in:

# 1. Check FCM token in Supabase SQL Editor:
# SELECT * FROM user_fcm_tokens ORDER BY last_updated DESC LIMIT 5;

# 2. Get your user ID:
# SELECT id, username FROM profiles WHERE username = 'YOUR_USERNAME';

# 3. Send test notification (replace YOUR_USER_ID):
# INSERT INTO notifications (recipient_id, sender_id, type, title, body)
# VALUES (
#   'YOUR_USER_ID',
#   'YOUR_USER_ID',
#   'reaction',
#   'Test Push Notification',
#   'If you see this on your phone, it works!'
# );

# 4. Check Edge Function logs:
supabase functions logs send-push-notification --tail

# ============================================
# TROUBLESHOOTING COMMANDS
# ============================================

# If deployment fails, check function logs:
supabase functions logs send-push-notification

# If you need to redeploy:
supabase functions deploy send-push-notification --no-verify-jwt

# If you need to update the secret:
supabase secrets set FIREBASE_SERVICE_ACCOUNT='NEW_JSON_HERE'

# List all secrets:
supabase secrets list

# Unset a secret (if needed):
supabase secrets unset FIREBASE_SERVICE_ACCOUNT

# Check function status:
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"record":{"recipient_id":"test","title":"Test","body":"Test"}}'

# ============================================
# USEFUL QUERIES FOR DEBUGGING
# ============================================

# See all queries in: test_push_notifications.sql

# Quick checks:

# 1. Check recent notifications:
# SELECT * FROM notifications ORDER BY created_at DESC LIMIT 10;

# 2. Check FCM tokens:
# SELECT * FROM user_fcm_tokens ORDER BY last_updated DESC;

# 3. Check Edge Function calls (pg_net):
# SELECT * FROM net._http_response ORDER BY created DESC LIMIT 10;

# ============================================
# OPTIONAL: LOCAL DEVELOPMENT
# ============================================

# Serve function locally for testing
supabase functions serve send-push-notification

# In another terminal, test it:
curl -X POST \
  http://localhost:54321/functions/v1/send-push-notification \
  -H "Content-Type: application/json" \
  -d '{"record":{"recipient_id":"test-user-id","sender_id":"test","type":"reaction","title":"Test","body":"Local test"}}'

# ============================================
# CLEANUP COMMANDS (if needed)
# ============================================

# Delete a deployed function:
supabase functions delete send-push-notification

# Unlink project:
supabase unlink

# ============================================
# SUCCESS INDICATORS
# ============================================

# ✅ You should see in Supabase CLI:
# - "Function deployed successfully"
# - "Secrets set successfully"

# ✅ You should see in Flutter console:
# - "FCM Token: ey..."

# ✅ You should see in Supabase Dashboard:
# - Edge Function listed under Functions
# - Tokens in user_fcm_tokens table
# - Notification in notifications table after insert

# ✅ You should receive on your phone:
# - Push notification when test inserted
# - Push notification when someone reacts/comments

# ============================================
# TIME ESTIMATES
# ============================================

# Step 1-2: Install & Login - 3 minutes
# Step 3: Link Project - 1 minute
# Step 4: Set Secret - 5 minutes (including JSON download)
# Step 5: Deploy Function - 2 minutes
# Step 6: Run Migration - 5 minutes
# Step 7-8: Test - 10 minutes
# Total: ~25-30 minutes

# ============================================
# NOTES
# ============================================

# - Make sure to replace ALL placeholders:
#   - YOUR_PROJECT_REF
#   - YOUR_SERVICE_ROLE_KEY
#   - YOUR_USER_ID
#   - FIREBASE JSON content

# - Keep your Service Role Key secret!
# - The Firebase Service Account JSON is sensitive
# - Test on a physical device, not emulator
# - Check Edge Function logs if notifications don't arrive
