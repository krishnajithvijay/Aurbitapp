-- =====================================================
-- Push Notification Trigger (Supabase Compatible Version)
-- This trigger calls the Supabase Edge Function whenever
-- a new notification is inserted into the notifications table
-- =====================================================

-- IMPORTANT: Supabase doesn't allow ALTER DATABASE in hosted environment
-- So we hardcode the values directly in the function (this is safe)

-- STEP 1: Enable pg_net extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- STEP 2: Create function to trigger push notification via Edge Function
CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    function_url TEXT;
    request_id BIGINT;
BEGIN
    -- Hardcoded values (replace with your actual values)
    -- Your Supabase URL
    function_url := 'https://henxsgquexgxvfwngjet.supabase.co/functions/v1/send-push-notification';
    
    -- Make async HTTP POST request to Edge Function
    -- Using anon key for webhook (Edge Function has service_role internally)
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

-- STEP 5: Grant necessary permissions (if needed)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT USAGE ON SCHEMA net TO authenticated;
    END IF;
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check if pg_net extension is enabled
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
        THEN '✓ pg_net extension enabled'
        ELSE '✗ pg_net extension NOT enabled - run: CREATE EXTENSION pg_net;'
    END as status;

-- Check if trigger exists
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'on_notification_created')
        THEN '✓ Trigger created successfully'
        ELSE '✗ Trigger NOT created'
    END as status;

-- =====================================================
-- TESTING
-- =====================================================

-- Test 1: Get a user ID for testing
-- SELECT id, username FROM profiles LIMIT 5;

-- Test 2: Insert a test notification (replace USER_ID with actual user ID)
/*
INSERT INTO notifications (recipient_id, sender_id, type, title, body)
VALUES (
  'YOUR_USER_ID_HERE',
  'YOUR_USER_ID_HERE',
  'reaction',
  'Test Push Notification',
  'If you see this on your phone, push notifications are working!'
);
*/

-- Test 3: Check if Edge Function was called
-- SELECT id, created, status_code, error_msg, 
--        LEFT(content::text, 100) as response_preview
-- FROM net._http_response 
-- ORDER BY created DESC 
-- LIMIT 5;

-- =====================================================
-- TROUBLESHOOTING
-- =====================================================

-- If trigger doesn't fire, check:
-- 1. pg_net extension enabled
-- 2. Trigger exists on notifications table
-- 3. Edge Function is deployed
-- 4. Edge Function URL is correct

-- View recent trigger executions:
-- SELECT * FROM net._http_response ORDER BY created DESC LIMIT 10;

-- =====================================================
-- NOTES
-- =====================================================
-- 1. This is 100% FREE - uses pg_net (included in Supabase)
-- 2. Works asynchronously - doesn't block notification inserts
-- 3. Handles errors gracefully
-- 4. Uses anon key (safe for this purpose - Edge Function validates)
-- 5. No ALTER DATABASE needed - works in Supabase hosted environment
