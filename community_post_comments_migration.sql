-- Migration for Community Post Comments
-- Supports nested replies similar to regular posts

-- Create community_post_comments table
CREATE TABLE IF NOT EXISTS community_post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_id UUID REFERENCES community_post_comments(id) ON DELETE CASCADE,
    reply_to_comment_id UUID REFERENCES community_post_comments(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_community_comments_post ON community_post_comments(post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_community_comments_user ON community_post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_community_comments_parent ON community_post_comments(parent_id);

-- Enable RLS
ALTER TABLE community_post_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Anyone can view comments
CREATE POLICY "Anyone can view community post comments"
    ON community_post_comments
    FOR SELECT
    USING (true);

-- Only community members can create comments
CREATE POLICY "Members can create comments"
    ON community_post_comments
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM community_posts cp
            JOIN community_members cm ON cp.community_id = cm.community_id
            WHERE cp.id = community_post_comments.post_id
            AND cm.user_id = auth.uid()
        )
    );

-- Users can update their own comments
CREATE POLICY "Users can update own comments"
    ON community_post_comments
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own comments
CREATE POLICY "Users can delete own comments"
    ON community_post_comments
    FOR DELETE
    USING (auth.uid() = user_id);

-- Comments
COMMENT ON TABLE community_post_comments IS 'Comments on community posts with nested reply support';
COMMENT ON COLUMN community_post_comments.parent_id IS 'Direct parent comment for threading';
COMMENT ON COLUMN community_post_comments.reply_to_comment_id IS 'Original comment being replied to';
