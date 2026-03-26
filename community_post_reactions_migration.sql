-- Migration for Community Post Reactions
-- This table stores user reactions to community posts with types: 'i_relate' and 'youre_not_alone'

-- Create community_post_reactions table
CREATE TABLE IF NOT EXISTS community_post_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL CHECK (reaction_type IN ('i_relate', 'youre_not_alone')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure a user can only have one reaction per community post
    UNIQUE(post_id, user_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_community_post_reactions_post_id ON community_post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_community_post_reactions_user_id ON community_post_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_community_post_reactions_type ON community_post_reactions(reaction_type);
CREATE INDEX IF NOT EXISTS idx_community_post_reactions_created_at ON community_post_reactions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE community_post_reactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all reactions
CREATE POLICY "Users can view all community post reactions"
    ON community_post_reactions
    FOR SELECT
    USING (true);

-- Policy: Users can insert their own reactions (only if they are community members)
CREATE POLICY "Members can insert their own reactions"
    ON community_post_reactions
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM community_posts cp
            JOIN community_members cm ON cp.community_id = cm.community_id
            WHERE cp.id = community_post_reactions.post_id
            AND cm.user_id = auth.uid()
        )
    );

-- Policy: Users can update their own reactions
CREATE POLICY "Users can update their own community post reactions"
    ON community_post_reactions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own reactions
CREATE POLICY "Users can delete their own community post reactions"
    ON community_post_reactions
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create a function to get reaction counts for a community post
CREATE OR REPLACE FUNCTION get_community_post_reaction_counts(p_post_id UUID)
RETURNS TABLE(
    i_relate_count BIGINT,
    youre_not_alone_count BIGINT,
    total_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE reaction_type = 'i_relate') AS i_relate_count,
        COUNT(*) FILTER (WHERE reaction_type = 'youre_not_alone') AS youre_not_alone_count,
        COUNT(*) AS total_count
    FROM community_post_reactions
    WHERE post_id = p_post_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create a function to check if a user has reacted to a community post
CREATE OR REPLACE FUNCTION get_user_community_post_reaction(p_post_id UUID, p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_reaction TEXT;
BEGIN
    SELECT reaction_type INTO user_reaction
    FROM community_post_reactions
    WHERE post_id = p_post_id AND user_id = p_user_id;
    
    RETURN user_reaction;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create a function to toggle user reaction on community posts
CREATE OR REPLACE FUNCTION toggle_community_post_reaction(
    p_post_id UUID,
    p_user_id UUID,
    p_reaction_type TEXT
)
RETURNS JSONB AS $$
DECLARE
    existing_reaction TEXT;
    result JSONB;
BEGIN
    -- Check if user already has a reaction on this community post
    SELECT reaction_type INTO existing_reaction
    FROM community_post_reactions
    WHERE post_id = p_post_id AND user_id = p_user_id;
    
    IF existing_reaction IS NULL THEN
        -- No existing reaction, insert new one
        INSERT INTO community_post_reactions (post_id, user_id, reaction_type)
        VALUES (p_post_id, p_user_id, p_reaction_type);
        
        result := jsonb_build_object(
            'action', 'added',
            'reaction_type', p_reaction_type
        );
    ELSIF existing_reaction = p_reaction_type THEN
        -- Same reaction, remove it (toggle off)
        DELETE FROM community_post_reactions
        WHERE post_id = p_post_id AND user_id = p_user_id;
        
        result := jsonb_build_object(
            'action', 'removed',
            'reaction_type', p_reaction_type
        );
    ELSE
        -- Different reaction, update it
        UPDATE community_post_reactions
        SET reaction_type = p_reaction_type, created_at = NOW()
        WHERE post_id = p_post_id AND user_id = p_user_id;
        
        result := jsonb_build_object(
            'action', 'updated',
            'old_reaction_type', existing_reaction,
            'new_reaction_type', p_reaction_type
        );
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Add comments to table
COMMENT ON TABLE community_post_reactions IS 'Stores user reactions to community posts with types: i_relate and youre_not_alone';
COMMENT ON COLUMN community_post_reactions.reaction_type IS 'Type of reaction: i_relate or youre_not_alone';
