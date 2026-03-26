-- Helper Script to analyze database state regarding FCM and Notifications

-- 1. Check if token exists for the user (The one we saw in logs)
SELECT 
    id, 
    user_id, 
    SUBSTRING(token, 1, 20) || '...' as token_preview,
    device_type, 
    last_updated 
FROM user_fcm_tokens 
WHERE user_id = 'f486d96b-2a40-4cbf-9662-e87f67bbc267';

-- 2. Check if a profile exists for this user (referential integrity)
SELECT id, username, email FROM profiles WHERE id = 'f486d96b-2a40-4cbf-9662-e87f67bbc267';

-- 3. Check recent notifications for this user
SELECT 
    id, 
    type, 
    title, 
    created_at 
FROM notifications 
WHERE recipient_id = 'f486d96b-2a40-4cbf-9662-e87f67bbc267'
ORDER BY created_at DESC 
LIMIT 5;

-- 4. Check if RLS is enabled on tokens table (should be true)
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'user_fcm_tokens';
