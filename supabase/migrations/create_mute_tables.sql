-- Create table for muted users (to hide their posts)
CREATE TABLE IF NOT EXISTS muted_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- The one attempting to mute
  muted_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, -- The one being muted
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, muted_user_id),
  CONSTRAINT no_self_mute CHECK (user_id != muted_user_id)
);

-- Create table for muted communities (to hide their posts from feed/notifications)
CREATE TABLE IF NOT EXISTS muted_communities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, community_id)
);

-- Enable RLS
ALTER TABLE muted_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE muted_communities ENABLE ROW LEVEL SECURITY;

-- Policies for muted_users
DROP POLICY IF EXISTS "Users can view their own mutes" ON muted_users;
CREATE POLICY "Users can view their own mutes" ON muted_users
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own mutes" ON muted_users;
CREATE POLICY "Users can insert their own mutes" ON muted_users
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own mutes" ON muted_users;
CREATE POLICY "Users can delete their own mutes" ON muted_users
  FOR DELETE USING (auth.uid() = user_id);

-- Policies for muted_communities
DROP POLICY IF EXISTS "Users can view their own community mutes" ON muted_communities;
CREATE POLICY "Users can view their own community mutes" ON muted_communities
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own community mutes" ON muted_communities;
CREATE POLICY "Users can insert their own community mutes" ON muted_communities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own community mutes" ON muted_communities;
CREATE POLICY "Users can delete their own community mutes" ON muted_communities
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_muted_users_user_id ON muted_users(user_id);
CREATE INDEX IF NOT EXISTS idx_muted_communities_user_id ON muted_communities(user_id);
