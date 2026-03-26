-- =====================================================
-- QUICK TESTING QUERIES FOR PUSH NOTIFICATIONS
-- =====================================================

-- 1. CHECK IF FCM TOKENS ARE BEING SAVED
-- Run this after logging into the app
SELECT 
    user_id,
    device_type,
    LEFT(token, 20) || '...' as token_preview,
    last_updated
FROM user_fcm_tokens
ORDER BY last_updated DESC
LIMIT 10;

-- 2. CHECK IF NOTIFICATIONS TABLE EXISTS AND HAS DATA  
SELECT 
    type,
    COUNT(*) as count,
    MAX(created_at) as last_created
FROM notifications
GROUP BY type
ORDER BY count DESC;

-- 3. CHECK IF TRIGGERS ARE INSTALLED
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name IN ('on_notification_created', 'trigger_notify_reaction', 'trigger_notify_comment', 'trigger_notify_reply');

-- 4. CHECK IF PG_NET EXTENSION IS ENABLED (for trigger approach)
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- 5. VERIFY PUSH NOTIFICATION FUNCTION EXISTS
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'trigger_push_notification'
AND routine_schema = 'public';

-- =====================================================
-- TEST PUSH NOTIFICATION MANUALLY
-- =====================================================

-- 6. INSERT TEST NOTIFICATION
-- IMPORTANT: Replace 'YOUR_USER_ID_HERE' with an actual user ID from profiles table
-- You can get your user ID by running: SELECT id, username FROM profiles LIMIT 5;

INSERT INTO notifications (recipient_id, sender_id, type, title, body)
VALUES (
    'YOUR_USER_ID_HERE',  -- Replace with actual user ID who has FCM token
    'YOUR_USER_ID_HERE',  -- Can be same for testing
    'reaction',
    'Test Push Notification',
    'If you see this on your phone, push notifications are working!'
);

-- 7. CHECK IF NOTIFICATION WAS CREATED
SELECT 
    id,
    type,
    title,
    body,
    created_at,
    is_read
FROM notifications
ORDER BY created_at DESC
LIMIT 5;

-- 8. CHECK PG_NET HTTP REQUESTS (if using trigger approach)
-- This shows if the Edge Function was called
SELECT 
    id,
    created,
    status_code,
    error_msg,
    LEFT(url, 50) as url_preview
FROM net._http_response
ORDER BY created DESC
LIMIT 10;

-- =====================================================
-- VERIFY USER HAS FCM TOKEN BEFORE TESTING
-- =====================================================

-- 9. Check if specific user has FCM token
-- Replace 'YOUR_USER_ID_HERE' with actual user ID
SELECT 
    u.username,
    f.device_type,
    f.last_updated,
    CASE 
        WHEN f.token IS NOT NULL THEN 'Has Token ✓'
        ELSE 'No Token ✗'
    END as token_status
FROM profiles u
LEFT JOIN user_fcm_tokens f ON u.id = f.user_id
WHERE u.id = 'YOUR_USER_ID_HERE';

-- =====================================================
-- CLEAN UP TEST DATA
-- =====================================================

-- 10. Delete test notifications (optional)
DELETE FROM notifications 
WHERE title = 'Test Push Notification'
AND created_at > NOW() - INTERVAL '1 hour';

-- =====================================================
-- MONITOR NOTIFICATION ACTIVITY
-- =====================================================

-- 11. See recent notification activity
SELECT 
    n.type,
    n.title,
    n.body,
    sender.username as sender,
    recipient.username as recipient,
    n.created_at,
    n.is_read
FROM notifications n
LEFT JOIN profiles sender ON n.sender_id = sender.id
LEFT JOIN profiles recipient ON n.recipient_id = recipient.id
ORDER BY n.created_at DESC
LIMIT 20;

-- 12. Count unread notifications per user
SELECT 
    p.username,
    COUNT(n.id) as unread_count
FROM profiles p
LEFT JOIN notifications n ON p.id = n.recipient_id AND n.is_read = false
GROUP BY p.id, p.username
HAVING COUNT(n.id) > 0
ORDER BY unread_count DESC;

-- =====================================================
-- TROUBLESHOOTING
-- =====================================================

-- 13. Check if Supabase settings are configured (for trigger approach)
SELECT 
    name, 
    setting,
    CASE 
        WHEN name = 'app.settings.supabase_url' THEN 
            CASE WHEN setting LIKE 'https://%' THEN '✓ Valid' ELSE '✗ Invalid' END
        WHEN name = 'app.settings.service_role_key' THEN
            CASE WHEN setting LIKE 'eyJ%' THEN '✓ Set' ELSE '✗ Not Set' END
    END as status
FROM pg_settings
WHERE name LIKE 'app.settings%';

-- 14. Check RLS policies on notifications table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'notifications';

-- 15. Verify user_fcm_tokens RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'user_fcm_tokens';
