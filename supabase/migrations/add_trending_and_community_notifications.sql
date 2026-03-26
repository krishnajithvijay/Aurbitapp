-- 1. Add community_post_id to notifications
ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS community_post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE;

-- 2. Function for Trending Posts (More than 2 comments)
CREATE OR REPLACE FUNCTION check_trending_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    comment_count INTEGER;
    post_author_id UUID;
BEGIN
    -- Count comments for this post
    SELECT count(*) INTO comment_count FROM comments WHERE post_id = NEW.post_id;

    -- Trigger ONLY when it hits exactly 3 comments ( > 2 )
    IF comment_count = 3 THEN
        -- Get post author
        SELECT user_id INTO post_author_id FROM posts WHERE id = NEW.post_id;
        
        -- Insert notification for ALL users (except author who might getting distinct notifications anyway)
        INSERT INTO notifications (recipient_id, sender_id, type, title, body, post_id)
        SELECT 
            id as recipient_id, 
            post_author_id as sender_id, -- Use author as sender (System notification via Author's avatar)
            'trending_post' as type,
            'Trending Post 🔥', 
            'A post is getting popular! Join the conversation.',
            NEW.post_id
        FROM profiles
        WHERE id != post_author_id; 
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Trigger for Trending Posts
DROP TRIGGER IF EXISTS trigger_trending_post ON comments;
CREATE TRIGGER trigger_trending_post
AFTER INSERT ON comments
FOR EACH ROW
EXECUTE FUNCTION check_trending_post();


-- 4. Function for Community Posts
CREATE OR REPLACE FUNCTION notify_community_members()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    community_name TEXT;
BEGIN
    -- Get Community Name
    SELECT name INTO community_name FROM communities WHERE id = NEW.community_id;

    -- Notify all members of the community (except the poster)
    -- Notify all members of the community (except the poster)
    INSERT INTO notifications (recipient_id, sender_id, type, title, body, community_post_id)
    SELECT 
        user_id as recipient_id, 
        NEW.user_id as sender_id,
        'community_new_post' as type,
        'New Post in ' || community_name,
        substring(NEW.content from 1 for 100), -- Preview
        NEW.id -- The community post ID
    FROM community_members
    WHERE community_id = NEW.community_id
    AND user_id != NEW.user_id;

    RETURN NEW;
END;
$$;

-- 5. Trigger for Community Posts
DROP TRIGGER IF EXISTS trigger_new_community_post ON community_posts;
CREATE TRIGGER trigger_new_community_post
AFTER INSERT ON community_posts
FOR EACH ROW
EXECUTE FUNCTION notify_community_members();
