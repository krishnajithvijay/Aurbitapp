-- Migration for Community Admin Features
-- Includes: bio, member management (kick, ban, restrict), and admin promotion

-- 1. Add bio column to communities table
ALTER TABLE communities 
ADD COLUMN IF NOT EXISTS bio TEXT;

-- 2. Create community_bans table to track banned users
CREATE TABLE IF NOT EXISTS community_bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    banned_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    banned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ban_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '20 days',
    reason TEXT,
    
    -- Prevent duplicate bans
    UNIQUE(community_id, user_id)
);

-- 3. Add restriction column to community_members table
ALTER TABLE community_members 
ADD COLUMN IF NOT EXISTS is_restricted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS restricted_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS restricted_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS restriction_reason TEXT;

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_community_bans_community ON community_bans(community_id);
CREATE INDEX IF NOT EXISTS idx_community_bans_user ON community_bans(user_id);
CREATE INDEX IF NOT EXISTS idx_community_bans_expires ON community_bans(ban_expires_at);
CREATE INDEX IF NOT EXISTS idx_community_members_restricted ON community_members(community_id, is_restricted);

-- 5. Enable Row Level Security
ALTER TABLE community_bans ENABLE ROW LEVEL SECURITY;

-- RLS Policies for community_bans

-- Anyone can view bans (to check if they're banned)
CREATE POLICY "Anyone can view community bans"
    ON community_bans
    FOR SELECT
    USING (true);

-- Only admins can create bans
CREATE POLICY "Admins can ban users"
    ON community_bans
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM community_members cm
            WHERE cm.community_id = community_bans.community_id
            AND cm.user_id = auth.uid()
            AND cm.role = 'admin'
        )
    );

-- Only admins can remove bans
CREATE POLICY "Admins can remove bans"
    ON community_bans
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM community_members cm
            WHERE cm.community_id = community_bans.community_id
            AND cm.user_id = auth.uid()
            AND cm.role = 'admin'
        )
    );

-- 6. Update RLS policy for community_posts to prevent restricted users from posting
DROP POLICY IF EXISTS "Members can create posts in their communities" ON community_posts;

CREATE POLICY "Members can create posts in their communities"
    ON community_posts
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM community_members cm
            WHERE cm.community_id = community_posts.community_id
            AND cm.user_id = auth.uid()
            AND cm.is_restricted = FALSE  -- Restricted users cannot post
        )
        AND EXISTS (
            SELECT 1 FROM communities c
            WHERE c.id = community_posts.community_id
            AND c.status = 'active'  -- Community must be active
        )
    );

-- 7. Add policy for admins to delete members (kick)
CREATE POLICY "Admins can kick members"
    ON community_members
    FOR DELETE
    USING (
        auth.uid() = user_id  -- Users can leave
        OR EXISTS (
            SELECT 1 FROM community_members cm
            WHERE cm.community_id = community_members.community_id
            AND cm.user_id = auth.uid()
            AND cm.role = 'admin'  -- Admins can kick
        )
    );

-- 8. Update policy for admins to restrict members
DROP POLICY IF EXISTS "Admins can update member roles" ON community_members;

CREATE POLICY "Admins can update members"
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

-- 9. Prevent users from joining if they're banned
CREATE OR REPLACE FUNCTION check_community_ban()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if user is currently banned
    IF EXISTS (
        SELECT 1 FROM community_bans
        WHERE community_id = NEW.community_id
        AND user_id = NEW.user_id
        AND ban_expires_at > NOW()
    ) THEN
        RAISE EXCEPTION 'User is banned from this community';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_community_ban ON community_members;
CREATE TRIGGER trigger_check_community_ban
    BEFORE INSERT ON community_members
    FOR EACH ROW
    EXECUTE FUNCTION check_community_ban();

-- 10. Function to check if user is banned from a community
CREATE OR REPLACE FUNCTION is_user_banned(p_community_id UUID, p_user_id UUID)
RETURNS TABLE(
    is_banned BOOLEAN,
    ban_expires_at TIMESTAMP WITH TIME ZONE,
    days_remaining INTEGER,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TRUE as is_banned,
        cb.ban_expires_at,
        EXTRACT(DAY FROM (cb.ban_expires_at - NOW()))::INTEGER as days_remaining,
        cb.reason
    FROM community_bans cb
    WHERE cb.community_id = p_community_id
    AND cb.user_id = p_user_id
    AND cb.ban_expires_at > NOW()
    LIMIT 1;
    
    -- If no active ban found, return false
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            FALSE as is_banned,
            NULL::TIMESTAMP WITH TIME ZONE as ban_expires_at,
            0 as days_remaining,
            NULL::TEXT as reason;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- 11. Function to check if user is admin of a community
CREATE OR REPLACE FUNCTION is_community_admin(p_community_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    is_admin BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM community_members
        WHERE community_id = p_community_id
        AND user_id = p_user_id
        AND role = 'admin'
    ) INTO is_admin;
    
    RETURN is_admin;
END;
$$ LANGUAGE plpgsql STABLE;

-- 12. Function to get community members with full details
CREATE OR REPLACE FUNCTION get_community_members_detailed(p_community_id UUID)
RETURNS TABLE(
    member_id UUID,
    user_id UUID,
    username TEXT,
    avatar_url TEXT,
    role TEXT,
    is_restricted BOOLEAN,
    restricted_at TIMESTAMP WITH TIME ZONE,
    restriction_reason TEXT,
    joined_at TIMESTAMP WITH TIME ZONE,
    is_verified BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.id as member_id,
        cm.user_id,
        p.username,
        p.avatar_url,
        cm.role,
        cm.is_restricted,
        cm.restricted_at,
        cm.restriction_reason,
        cm.joined_at,
        COALESCE(p.is_verified, FALSE) as is_verified
    FROM community_members cm
    JOIN profiles p ON cm.user_id = p.id
    WHERE cm.community_id = p_community_id
    ORDER BY 
        CASE cm.role 
            WHEN 'admin' THEN 1 
            WHEN 'moderator' THEN 2 
            ELSE 3 
        END,
        cm.joined_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- 13. Update communities table policies to allow admins to update bio and name
DROP POLICY IF EXISTS "Owner can update community" ON communities;

CREATE POLICY "Admins can update community"
    ON communities
    FOR UPDATE
    USING (
        -- Owner can update
        auth.uid() = created_by
        OR
        -- Admins can update
        EXISTS (
            SELECT 1 FROM community_members cm
            WHERE cm.community_id = communities.id
            AND cm.user_id = auth.uid()
            AND cm.role = 'admin'
        )
    );

-- 14. Auto-cleanup expired bans (optional - runs periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_bans()
RETURNS void AS $$
BEGIN
    DELETE FROM community_bans
    WHERE ban_expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- 15. Comments
COMMENT ON TABLE community_bans IS 'Tracks banned users from communities with 20-day expiration';
COMMENT ON COLUMN community_bans.ban_expires_at IS 'Ban automatically expires after 20 days';
COMMENT ON COLUMN community_members.is_restricted IS 'Restricted users cannot post but can view content';
COMMENT ON COLUMN community_members.restriction_reason IS 'Reason why the user was restricted';
COMMENT ON COLUMN communities.bio IS 'Community biography/description shown to all members';
