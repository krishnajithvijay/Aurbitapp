# 🔄 Two Methods to Trigger Push Notifications

You have **TWO options** to trigger the Edge Function when notifications are created. Choose the one you prefer:

---

## ⚡ METHOD 1: Database Trigger (pg_net) - FREE, FAST ✅ RECOMMENDED

### Pros:
- ✅ 100% Free (no limits)
- ✅ Faster (runs in database)
- ✅ More reliable
- ✅ No webhook quotas

### Cons:
- ⚠️ Requires running SQL

### Setup:

**STEP 1:** Copy the entire contents of `push_notification_trigger.sql` (updated version)

**STEP 2:** Go to Supabase Dashboard → SQL Editor → New Query

**STEP 3:** Paste and click **Run**

**STEP 4:** Verify with these queries:
```sql
-- Should return: ✓ pg_net extension enabled
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
        THEN '✓ pg_net extension enabled'
        ELSE '✗ pg_net extension NOT enabled'
    END as status;

-- Should return: ✓ Trigger created successfully
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'on_notification_created')
        THEN '✓ Trigger created successfully'
        ELSE '✗ Trigger NOT created'
    END as status;
```

**Done!** ✅

---

## 🌐 METHOD 2: Supabase Dashboard Webhook - EASIER

### Pros:
- ✅ No SQL needed
- ✅ Visual setup
- ✅ Easy to understand

### Cons:
- ⚠️ Limited to 500K calls/month (still free)
- ⚠️ Slightly slower
- ⚠️ Webhook quotas apply

### Setup:

**STEP 1:** Go to Supabase Dashboard → Database → Webhooks

**STEP 2:** Click "Create a new webhook"

**STEP 3:** Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `push-notification-webhook` |
| **Table** | `notifications` |
| **Events** | ✅ INSERT (check only this) |
| **Type** | HTTP Request |
| **Method** | POST |
| **URL** | `https://henxsgquexgxvfwngjet.supabase.co/functions/v1/send-push-notification` |

**STEP 4:** Add HTTP Headers:

Click "Add header" twice and add:

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlbnhzZ3F1ZXhneHZmd25namV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjg4NTIsImV4cCI6MjA4NDUwNDg1Mn0.qhovSln6868wGsK-7jqM9D-C2133_Gcpj-E1uX4QHg0` |
| `Content-Type` | `application/json` |

**STEP 5:** Click "Create webhook"

**Done!** ✅

---

## 🧪 Testing Both Methods

After setting up either method, test with this SQL:

```sql
-- 1. Get your user ID
SELECT id, username FROM profiles LIMIT 5;

-- 2. Insert test notification (replace YOUR_USER_ID)
INSERT INTO notifications (recipient_id, sender_id, type, title, body)
VALUES (
  'YOUR_USER_ID_HERE',
  'YOUR_USER_ID_HERE',
  'reaction',
  'Test Push Notification',
  'If you see this on your phone, it works!'
);

-- 3. Check if it was triggered:

-- FOR METHOD 1 (pg_net):
SELECT id, created, status_code, error_msg
FROM net._http_response 
ORDER BY created DESC 
LIMIT 5;

-- FOR METHOD 2 (Webhook):
-- Check in: Supabase Dashboard → Database → Webhooks → View logs
```

---

## 🎯 Which Method Should You Use?

### Use METHOD 1 (pg_net) if:
- ✅ You want the best performance
- ✅ You want unlimited free calls
- ✅ You're comfortable running SQL
- ✅ You want the most reliable solution

### Use METHOD 2 (Webhook) if:
- ✅ You prefer visual UI setup
- ✅ You don't want to run SQL
- ✅ 500K calls/month is enough for you
- ✅ You want easier troubleshooting (webhook logs)

**My Recommendation**: **METHOD 1 (pg_net)** - Better in every way except ease of setup

---

## 📊 Comparison Table

| Feature | Method 1 (pg_net) | Method 2 (Webhook) |
|---------|-------------------|-------------------|
| **Cost** | FREE (unlimited) | FREE (up to 500K/month) |
| **Speed** | ⚡ Faster | Slightly slower |
| **Reliability** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Setup Difficulty** | SQL required | Visual UI |
| **Limits** | None | 500K/month |
| **Troubleshooting** | SQL queries | Dashboard UI |
| **Recommended?** | ✅ YES | Good alternative |

---

## ✅ Current Status

You already have:
- ✅ Edge Function code created
- ✅ SQL trigger file fixed and ready
- ✅ Your Supabase URL and keys
- ✅ FCM tokens being saved to database

**What's left:**
1. Deploy Edge Function (5-10 min)
2. Choose and setup trigger method (5 min)
3. Test (5 min)

**Total time remaining: ~20 minutes**

---

## 🆘 If You're Stuck

### Can't decide which method?
→ Just use **METHOD 1** - It's the best option

### METHOD 1 not working?
→ Run the verification queries to check pg_net and trigger
→ Check `SELECT * FROM net._http_response`

### METHOD 2 not working?
→ Check webhook logs in Dashboard
→ Verify URL and authorization header are correct

### Neither working?
→ Make sure Edge Function is deployed first!
→ Use `test_push_notifications.sql` for debugging

---

## 📝 Next Steps After Setup

1. ✅ Setup trigger (either method)
2. ✅ Test with manual notification insert
3. ✅ Verify push received on phone
4. ✅ Test with real actions (react/comment)
5. ✅ Monitor Edge Function logs
6. 🎉 Celebrate - you're done!

**Choose your method and let's finish this!** 🚀
