-- SQL Script to Trigger a Test Notification
-- We explicitly set the ID of the user we know has logged in: f486d96b-2a40-4cbf-9662-e87f67bbc267

DO $$
DECLARE
    target_user UUID := 'f486d96b-2a40-4cbf-9662-e87f67bbc267';
BEGIN
    INSERT INTO notifications (
        recipient_id,
        sender_id,
        type,
        title,
        body
    ) VALUES (
        target_user,
        target_user,
        'message',
        'Direct Test',
        'This notification targets your specific user ID.'
    );
END $$;
