-- Migration for Notifications System
-- Handles notifications for reactions, comments, replies, and orbit requests

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('reaction', 'comment', 'reply', 'orbit_request', 'orbit_accept', 'message')),
    
    -- Reference IDs (nullable based on type)
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    reaction_type TEXT CHECK (reaction_type IN ('i_relate', 'youre_not_alone')),
    orbit_type TEXT CHECK (orbit_type IN ('inner', 'outer')),
    
    -- Notification content
    title TEXT NOT NULL,
    body TEXT,
    
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevent duplicate notifications for same action
    UNIQUE(recipient_id, sender_id, type, post_id, comment_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(recipient_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_sender ON notifications(sender_id);

-- Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications
    FOR SELECT
    USING (auth.uid() = recipient_id);

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications"
    ON notifications
    FOR UPDATE
    USING (auth.uid() = recipient_id)
    WITH CHECK (auth.uid() = recipient_id);

-- Policy: System can insert notifications (we'll use service role or triggers)
CREATE POLICY "Authenticated users can insert notifications"
    ON notifications
    FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
    ON notifications
    FOR DELETE
    USING (auth.uid() = recipient_id);

-- Function to create notification for post reaction
CREATE OR REPLACE FUNCTION notify_post_reaction()
RETURNS TRIGGER AS $$
DECLARE
    post_owner_id UUID;
    sender_username TEXT;
    reaction_label TEXT;
BEGIN
    -- Get post owner
    SELECT user_id INTO post_owner_id FROM posts WHERE id = NEW.post_id;
    
    -- Don't notify if user reacted to their own post
    IF post_owner_id = NEW.user_id THEN
        RETURN NEW;
    END IF;
    
    -- Get sender username
    SELECT username INTO sender_username FROM profiles WHERE id = NEW.user_id;
    
    -- Get reaction label
    reaction_label := CASE 
        WHEN NEW.reaction_type = 'i_relate' THEN 'related to your post'
        WHEN NEW.reaction_type = 'youre_not_alone' THEN 'sent "You''re not alone"'
        ELSE 'reacted to your post'
    END;
    
    -- Insert notification (ignore if duplicate)
    INSERT INTO notifications (
        recipient_id,
        sender_id,
        type,
        post_id,
        reaction_type,
        title,
        body
    ) VALUES (
        post_owner_id,
        NEW.user_id,
        'reaction',
        NEW.post_id,
        NEW.reaction_type,
        sender_username || ' ' || reaction_label,
        NULL
    )
    ON CONFLICT (recipient_id, sender_id, type, post_id, comment_id) 
    DO UPDATE SET 
        created_at = NOW(),
        is_read = FALSE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create notification for comment
CREATE OR REPLACE FUNCTION notify_post_comment()
RETURNS TRIGGER AS $$
DECLARE
    post_owner_id UUID;
    sender_username TEXT;
    comment_preview TEXT;
BEGIN
    -- Get post owner
    SELECT user_id INTO post_owner_id FROM posts WHERE id = NEW.post_id;
    
    -- Don't notify if user commented on their own post
    IF post_owner_id = NEW.user_id THEN
        RETURN NEW;
    END IF;
    
    -- Get sender username
    SELECT username INTO sender_username FROM profiles WHERE id = NEW.user_id;
    
    -- Create comment preview (first 50 chars)
    comment_preview := LEFT(NEW.content, 50);
    IF LENGTH(NEW.content) > 50 THEN
        comment_preview := comment_preview || '...';
    END IF;
    
    -- Insert notification
    INSERT INTO notifications (
        recipient_id,
        sender_id,
        type,
        post_id,
        comment_id,
        title,
        body
    ) VALUES (
        post_owner_id,
        NEW.user_id,
        'comment',
        NEW.post_id,
        NEW.id,
        sender_username || ' commented on your post',
        comment_preview
    )
    ON CONFLICT (recipient_id, sender_id, type, post_id, comment_id) 
    DO UPDATE SET 
        created_at = NOW(),
        is_read = FALSE,
        body = EXCLUDED.body;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create notification for comment reply
CREATE OR REPLACE FUNCTION notify_comment_reply()
RETURNS TRIGGER AS $$
DECLARE
    parent_comment_owner_id UUID;
    sender_username TEXT;
    reply_preview TEXT;
BEGIN
    -- Only process if this is a reply (has parent_id)
    IF NEW.parent_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Get parent comment owner
    SELECT user_id INTO parent_comment_owner_id FROM comments WHERE id = NEW.parent_id;
    
    -- Don't notify if user replied to their own comment
    IF parent_comment_owner_id = NEW.user_id THEN
        RETURN NEW;
    END IF;
    
    -- Get sender username
    SELECT username INTO sender_username FROM profiles WHERE id = NEW.user_id;
    
    -- Create reply preview
    reply_preview := LEFT(NEW.content, 50);
    IF LENGTH(NEW.content) > 50 THEN
        reply_preview := reply_preview || '...';
    END IF;
    
    -- Insert notification
    INSERT INTO notifications (
        recipient_id,
        sender_id,
        type,
        post_id,
        comment_id,
        title,
        body
    ) VALUES (
        parent_comment_owner_id,
        NEW.user_id,
        'reply',
        NEW.post_id,
        NEW.id,
        sender_username || ' replied to your comment',
        reply_preview
    )
    ON CONFLICT (recipient_id, sender_id, type, post_id, comment_id) 
    DO UPDATE SET 
        created_at = NOW(),
        is_read = FALSE,
        body = EXCLUDED.body;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS trigger_notify_reaction ON post_reactions;
CREATE TRIGGER trigger_notify_reaction
    AFTER INSERT ON post_reactions
    FOR EACH ROW
    EXECUTE FUNCTION notify_post_reaction();

DROP TRIGGER IF EXISTS trigger_notify_comment ON comments;
CREATE TRIGGER trigger_notify_comment
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_post_comment();

DROP TRIGGER IF EXISTS trigger_notify_reply ON comments;
CREATE TRIGGER trigger_notify_reply
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_comment_reply();

-- Function to mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read(user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE notifications
    SET is_read = TRUE
    WHERE recipient_id = user_id AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    unread_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unread_count
    FROM notifications
    WHERE recipient_id = user_id AND is_read = FALSE;
    
    RETURN unread_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Add comments
COMMENT ON TABLE notifications IS 'Stores all user notifications for reactions, comments, replies, and orbit requests';
COMMENT ON COLUMN notifications.type IS 'Type of notification: reaction, comment, reply, orbit_request, orbit_accept, message';
COMMENT ON COLUMN notifications.is_read IS 'Whether the notification has been read by the recipient';
