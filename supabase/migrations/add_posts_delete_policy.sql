-- Migration: Add RLS policies for posts deletion
-- Description: Allow users to delete their own posts in the public 'posts' table.

-- Enable RLS on posts table (idempotent if already enabled)
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can delete their own posts
DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;
CREATE POLICY "Users can delete their own posts"
ON posts FOR DELETE
USING (
  auth.uid() = user_id
);

-- Policy: Users can insert their own posts
DROP POLICY IF EXISTS "Users can insert their own posts" ON posts;
CREATE POLICY "Users can insert their own posts"
ON posts FOR INSERT
WITH CHECK (
  auth.uid() = user_id
);

-- Policy: Everyone can view posts (assuming public feed)
DROP POLICY IF EXISTS "Everyone can view posts" ON posts;
CREATE POLICY "Everyone can view posts"
ON posts FOR SELECT
USING (true);
