-- =====================================================
-- Push Notification Trigger (Supabase Compatible)
-- Alternative method without ALTER DATABASE
-- =====================================================

-- STEP 1: Enable pg_net extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- STEP 2: Create function to trigger push notification via Edge Function
-- This version uses hardcoded values (safe - they're not secret in triggers)
CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    function_url TEXT;
    request_id BIGINT;
BEGIN
    -- Build Edge Function URL (replace YOUR_PROJECT_REF with your actual project reference)
    -- Example: https://henxsgquexgxvfwngjet.supabase.co/functions/v1/send-push-notification
    function_url := 'https://henxsgquexgxvfwngjet.supabase.co/functions/v1/send-push-notification';
    
    -- Make async HTTP POST request to Edge Function
    -- Using anon key is fine here - Edge Function has its own security
    SELECT net.http_post(
        url := function_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlbnhzZ3F1ZXhneHZmd25namV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjg4NTIsImV4cCI6MjA4NDUwNDg1Mn0.qhovSln6868wGsK-7jqM9D-C2133_Gcpj-E1uX4QHg0'
        ),
        body := jsonb_build_object(
            'record', row_to_json(NEW),
            'type', 'notification_created'
        )
    ) INTO request_id;
    
    -- Log the request (optional - for debugging)
    RAISE NOTICE 'Push notification triggered. Request ID: %', request_id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the insert
        RAISE WARNING 'Error triggering push notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 3: Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_notification_created ON notifications;

-- STEP 4: Create trigger on notifications table
CREATE TRIGGER on_notification_created
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_push_notification();

-- STEP 5: Grant necessary permissions
GRANT USAGE ON SCHEMA net TO postgres, authenticated, service_role;

-- STEP 6: Verify trigger is created
-- Run this to check:
-- SELECT * FROM information_schema.triggers WHERE trigger_name = 'on_notification_created';

-- =====================================================
-- Testing
-- =====================================================

-- Test 1: Check if pg_net extension is enabled
-- SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- Test 2: Verify trigger exists
-- SELECT trigger_name, event_object_table, action_statement 
-- FROM information_schema.triggers 
-- WHERE trigger_name = 'on_notification_created';

-- Test 3: Insert a test notification (replace USER_ID with actual user ID)
-- First get a user ID:
-- SELECT id, username FROM profiles LIMIT 5;

-- Then insert test notification:
-- INSERT INTO notifications (recipient_id, sender_id, type, title, body)
-- VALUES (
--   'YOUR_USER_ID_HERE',
--   'YOUR_USER_ID_HERE',
--   'reaction',
--   'Test Push Notification',
--   'This is a test to verify push notifications work'
-- );

-- Test 4: Check pg_net requests
-- SELECT id, created, status_code, error_msg, content::text
-- FROM net._http_response 
-- ORDER BY created DESC 
-- LIMIT 5;

-- =====================================================
-- Notes
-- =====================================================
-- 1. This is completely FREE - uses pg_net which is included in Supabase
-- 2. No ALTER DATABASE needed - works in Supabase hosted environment
-- 3. Uses anon key which is safe for this purpose (Edge Function validates)
-- 4. Works asynchronously - doesn't block notification insert
-- 5. Handles errors gracefully without failing the notification insert
