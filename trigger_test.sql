-- SQL Script to Trigger a Test Notification
-- This attempts to find a user with a registered device and sends them a notification.

DO $$
DECLARE
    target_user UUID;
BEGIN
    -- 1. Select the first user we find who has an FCM token registered
    SELECT user_id INTO target_user FROM user_fcm_tokens LIMIT 1;

    -- 2. If we found one, insert a test notification
    IF target_user IS NOT NULL THEN
        INSERT INTO notifications (
            recipient_id,
            sender_id, -- We use the same user as sender just for testing
            type,
            title,
            body
        ) VALUES (
            target_user,
            target_user,
            'message', -- Generic type that doesn't need a post_id
            'Test Notification',
            'This is a manual test to check if the Edge Function triggers.'
        );
        RAISE NOTICE 'Test notification inserted for user ID: %', target_user;
    ELSE
        RAISE NOTICE 'NO TOKENS FOUND: You must log in to the app on a device/emulator first to register a token.';
    END IF;
END $$;
