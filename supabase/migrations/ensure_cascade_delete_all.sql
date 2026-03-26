-- Comprehensive delete cascade fix
-- This ensures that when a user/profile is deleted, all their related data is removed automatically
-- preventing foreign key constraint errors.

-- 1. POSTS
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_user_id_fkey;
ALTER TABLE posts ADD CONSTRAINT posts_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 2. COMMENTS
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_user_id_fkey;
ALTER TABLE comments ADD CONSTRAINT comments_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 3. NOTIFICATIONS (Recipient and Sender)
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey; -- Legacy name? check schema.
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_recipient_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_recipient_id_fkey 
    FOREIGN KEY (recipient_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_sender_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_sender_id_fkey 
    FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 4. COMMUNITY MEMBERS
ALTER TABLE community_members DROP CONSTRAINT IF EXISTS community_members_user_id_fkey;
ALTER TABLE community_members ADD CONSTRAINT community_members_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 5. COMMUNITY POSTS
ALTER TABLE community_posts DROP CONSTRAINT IF EXISTS community_posts_user_id_fkey;
ALTER TABLE community_posts ADD CONSTRAINT community_posts_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 6. USER ORBITS
ALTER TABLE user_orbits DROP CONSTRAINT IF EXISTS user_orbits_user_id_fkey;
ALTER TABLE user_orbits ADD CONSTRAINT user_orbits_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 7. LIKES / REACTIONS (Check table name, assuming 'post_reactions' or 'likes')
-- We'll try generic names found in migrations
-- 'post_reactions_migration.sql' exists
ALTER TABLE post_reactions DROP CONSTRAINT IF EXISTS post_reactions_user_id_fkey;
ALTER TABLE post_reactions ADD CONSTRAINT post_reactions_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 8. REPORTS (If exists)
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
ALTER TABLE reports ADD CONSTRAINT reports_reporter_id_fkey 
    FOREIGN KEY (reporter_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reported_id_fkey;
ALTER TABLE reports ADD CONSTRAINT reports_reported_id_fkey 
    FOREIGN KEY (reported_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 9. USER BLOCKS
ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS user_blocks_blocker_id_fkey;
ALTER TABLE user_blocks ADD CONSTRAINT user_blocks_blocker_id_fkey 
    FOREIGN KEY (blocker_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE user_blocks DROP CONSTRAINT IF EXISTS user_blocks_blocked_id_fkey;
ALTER TABLE user_blocks ADD CONSTRAINT user_blocks_blocked_id_fkey 
    FOREIGN KEY (blocked_id) REFERENCES profiles(id) ON DELETE CASCADE;
