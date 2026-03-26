-- Create user_orbits table for friend/orbit relationships
-- Migration: create_user_orbits_table
-- Created: 2026-01-22

-- Create the user_orbits table
CREATE TABLE IF NOT EXISTS user_orbits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  orbit_type TEXT NOT NULL CHECK (orbit_type IN ('inner', 'outer')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  
  -- Prevent duplicate friendships
  CONSTRAINT unique_user_friend UNIQUE(user_id, friend_id),
  
  -- Prevent users from adding themselves
  CONSTRAINT no_self_orbit CHECK (user_id != friend_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_user_orbits_user_id ON user_orbits(user_id);
CREATE INDEX IF NOT EXISTS idx_user_orbits_friend_id ON user_orbits(friend_id);
CREATE INDEX IF NOT EXISTS idx_user_orbits_orbit_type ON user_orbits(orbit_type);
CREATE INDEX IF NOT EXISTS idx_user_orbits_created_at ON user_orbits(created_at DESC);

-- Enable Row Level Security
ALTER TABLE user_orbits ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own orbits" ON user_orbits;
DROP POLICY IF EXISTS "Users can view orbits where they are friends" ON user_orbits;
DROP POLICY IF EXISTS "Users can add to their orbit" ON user_orbits;
DROP POLICY IF EXISTS "Users can update their orbit" ON user_orbits;
DROP POLICY IF EXISTS "Users can remove from their orbit" ON user_orbits;

-- RLS Policy: Users can view their own orbits
CREATE POLICY "Users can view their own orbits"
  ON user_orbits FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policy: Users can view orbits where they are the friend (to see who added them)
CREATE POLICY "Users can view orbits where they are friends"
  ON user_orbits FOR SELECT
  USING (auth.uid() = friend_id);

-- RLS Policy: Users can add friends to their orbit
CREATE POLICY "Users can add to their orbit"
  ON user_orbits FOR INSERT
  WITH CHECK (auth.uid() = user_id AND user_id != friend_id);

-- RLS Policy: Users can update their orbit (change inner/outer)
CREATE POLICY "Users can update their orbit"
  ON user_orbits FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can remove from their orbit
CREATE POLICY "Users can remove from their orbit"
  ON user_orbits FOR DELETE
  USING (auth.uid() = user_id);

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_orbits_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update updated_at on updates
DROP TRIGGER IF EXISTS update_user_orbits_updated_at_trigger ON user_orbits;
CREATE TRIGGER update_user_orbits_updated_at_trigger
  BEFORE UPDATE ON user_orbits
  FOR EACH ROW
  EXECUTE FUNCTION update_user_orbits_updated_at();

-- Grant necessary permissions
GRANT ALL ON user_orbits TO authenticated;

-- Add helpful comments
COMMENT ON TABLE user_orbits IS 'Stores user friendship/orbit relationships';
COMMENT ON COLUMN user_orbits.user_id IS 'The user who owns this orbit (who added the friend)';
COMMENT ON COLUMN user_orbits.friend_id IS 'The user who was added to the orbit';
COMMENT ON COLUMN user_orbits.orbit_type IS 'Type of orbit: inner (close friends) or outer (casual connections)';
