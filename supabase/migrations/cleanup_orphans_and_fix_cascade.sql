-- Clean up orphan data and apply ON DELETE CASCADE constraints
-- This script first removes data that references non-existent users (orphans),
-- then updates the foreign keys to automatically handle future deletions.

-- 1. CLEANUP ORPHANS (Data pointing to deleted users)
DELETE FROM messages WHERE sender_id NOT IN (SELECT id FROM profiles);
DELETE FROM messages WHERE receiver_id NOT IN (SELECT id FROM profiles);

DELETE FROM posts WHERE user_id NOT IN (SELECT id FROM profiles);

DELETE FROM comments WHERE user_id NOT IN (SELECT id FROM profiles);

-- Check both potential column names key for notifications
DELETE FROM notifications WHERE recipient_id NOT IN (SELECT id FROM profiles);
DELETE FROM notifications WHERE sender_id IS NOT NULL AND sender_id NOT IN (SELECT id FROM profiles);

DELETE FROM community_members WHERE user_id NOT IN (SELECT id FROM profiles);

DELETE FROM community_posts WHERE user_id NOT IN (SELECT id FROM profiles);

DELETE FROM user_orbits WHERE user_id NOT IN (SELECT id FROM profiles);

DELETE FROM post_reactions WHERE user_id NOT IN (SELECT id FROM profiles);

DELETE FROM user_blocks WHERE blocker_id NOT IN (SELECT id FROM profiles);
DELETE FROM user_blocks WHERE blocked_id NOT IN (SELECT id FROM profiles);


-- 2. APPLY CASCADE CONSTRAINTS
-- Now that data is clean, we can enforce strict references with CASCADE

-- MESSAGES
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_receiver_id_fkey;
ALTER TABLE messages ADD CONSTRAINT messages_receiver_id_fkey 
    FOREIGN KEY (receiver_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;
ALTER TABLE messages ADD CONSTRAINT messages_sender_id_fkey 
    FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- POSTS
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_user_id_fkey;
ALTER TABLE posts ADD CONSTRAINT posts_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- COMMENTS
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_user_id_fkey;
ALTER TABLE comments ADD CONSTRAINT comments_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- NOTIFICATIONS
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_recipient_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_recipient_id_fkey 
    FOREIGN KEY (recipient_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_sender_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_sender_id_fkey 
    FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- COMMUNITY MEMBERS
ALTER TABLE community_members DROP CONSTRAINT IF EXISTS community_members_user_id_fkey;
ALTER TABLE community_members ADD CONSTRAINT community_members_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- COMMUNITY POSTS
ALTER TABLE community_posts DROP CONSTRAINT IF EXISTS community_posts_user_id_fkey;
ALTER TABLE community_posts ADD CONSTRAINT community_posts_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- USER ORBITS
ALTER TABLE user_orbits DROP CONSTRAINT IF EXISTS user_orbits_user_id_fkey;
ALTER TABLE user_orbits ADD CONSTRAINT user_orbits_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- REACTIONS
ALTER TABLE post_reactions DROP CONSTRAINT IF EXISTS post_reactions_user_id_fkey;
ALTER TABLE post_reactions ADD CONSTRAINT post_reactions_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- BLOCKS
ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS user_blocks_blocker_id_fkey;
ALTER TABLE user_blocks ADD CONSTRAINT user_blocks_blocker_id_fkey 
    FOREIGN KEY (blocker_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS user_blocks_blocked_id_fkey;
ALTER TABLE user_blocks ADD CONSTRAINT user_blocks_blocked_id_fkey 
    FOREIGN KEY (blocked_id) REFERENCES profiles(id) ON DELETE CASCADE;
