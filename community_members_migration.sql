-- Migration for Community Members and Posts
-- Tracks community membership and allows members to post within communities

-- Create community_members table (if not exists, update if exists)
CREATE TABLE IF NOT EXISTS community_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevent duplicate memberships
    UNIQUE(community_id, user_id)
);

-- Create community_posts table
CREATE TABLE IF NOT EXISTS community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    mood TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_community_members_community ON community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_joined ON community_members(joined_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_community ON community_posts(community_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_user ON community_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON community_posts(created_at DESC);

-- Enable Row Level Security
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for community_members

-- Anyone can view community members
CREATE POLICY "Anyone can view community members"
    ON community_members
    FOR SELECT
    USING (true);

-- Users can join communities (insert their own membership)
CREATE POLICY "Users can join communities"
    ON community_members
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can leave communities (delete their own membership)
CREATE POLICY "Users can leave communities"
    ON community_members
    FOR DELETE
    USING (auth.uid() = user_id);

-- Admins can update member roles
CREATE POLICY "Admins can update member roles"
    ON community_members
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM community_members cm
            WHERE cm.community_id = community_members.community_id
            AND cm.user_id = auth.uid()
            AND cm.role = 'admin'
        )
    );

-- RLS Policies for community_posts

-- Anyone can view community posts
CREATE POLICY "Anyone can view community posts"
    ON community_posts
    FOR SELECT
    USING (true);

-- Only community members can create posts
CREATE POLICY "Members can create posts in their communities"
    ON community_posts
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM community_members
            WHERE community_id = community_posts.community_id
            AND user_id = auth.uid()
        )
    );

-- Users can update their own posts
CREATE POLICY "Users can update their own posts"
    ON community_posts
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own posts
CREATE POLICY "Users can delete their own posts"
    ON community_posts
    FOR DELETE
    USING (auth.uid() = user_id);

-- Function to get community member count
CREATE OR REPLACE FUNCTION get_community_member_count(p_community_id UUID)
RETURNS INTEGER AS $$
DECLARE
    member_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO member_count
    FROM community_members
    WHERE community_id = p_community_id;
    
    RETURN member_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check if user is member of community
CREATE OR REPLACE FUNCTION is_community_member(p_community_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    is_member BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM community_members
        WHERE community_id = p_community_id
        AND user_id = p_user_id
    ) INTO is_member;
    
    RETURN is_member;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get community posts with user info
CREATE OR REPLACE FUNCTION get_community_posts_with_users(p_community_id UUID)
RETURNS TABLE(
    post_id UUID,
    content TEXT,
    mood TEXT,
    is_anonymous BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    user_id UUID,
    username TEXT,
    avatar_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.id as post_id,
        cp.content,
        cp.mood,
        cp.is_anonymous,
        cp.created_at,
        cp.user_id,
        CASE 
            WHEN cp.is_anonymous THEN 'Anonymous'
            ELSE p.username
        END as username,
        CASE 
            WHEN cp.is_anonymous THEN NULL
            ELSE p.avatar_url
        END as avatar_url
    FROM community_posts cp
    JOIN profiles p ON cp.user_id = p.id
    WHERE cp.community_id = p_community_id
    ORDER BY cp.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger to update community member count when someone joins
CREATE OR REPLACE FUNCTION update_community_member_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the communities table member count if that column exists
    -- This assumes you have a member_count column in communities table
    UPDATE communities
    SET member_count = (
        SELECT COUNT(*) FROM community_members
        WHERE community_id = NEW.community_id
    )
    WHERE id = NEW.community_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for member count on insert
DROP TRIGGER IF EXISTS trigger_update_member_count_insert ON community_members;
CREATE TRIGGER trigger_update_member_count_insert
    AFTER INSERT ON community_members
    FOR EACH ROW
    EXECUTE FUNCTION update_community_member_count();

-- Trigger for member count on delete
CREATE OR REPLACE FUNCTION update_community_member_count_delete()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE communities
    SET member_count = (
        SELECT COUNT(*) FROM community_members
        WHERE community_id = OLD.community_id
    )
    WHERE id = OLD.community_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_member_count_delete ON community_members;
CREATE TRIGGER trigger_update_member_count_delete
    AFTER DELETE ON community_members
    FOR EACH ROW
    EXECUTE FUNCTION update_community_member_count_delete();

-- Add member_count column to communities if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'communities' 
        AND column_name = 'member_count'
    ) THEN
        ALTER TABLE communities ADD COLUMN member_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- Update existing member counts
UPDATE communities c
SET member_count = (
    SELECT COUNT(*) FROM community_members cm
    WHERE cm.community_id = c.id
);

-- Comments
COMMENT ON TABLE community_members IS 'Tracks which users are members of which communities';
COMMENT ON TABLE community_posts IS 'Posts created by members within communities';
COMMENT ON COLUMN community_members.role IS 'User role in community: admin, moderator, or member';
COMMENT ON COLUMN community_members.joined_at IS 'When the user joined the community';
COMMENT ON COLUMN community_posts.is_anonymous IS 'Whether the post is anonymous within the community';
