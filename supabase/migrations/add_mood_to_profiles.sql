-- Migration: Add mood tracking columns to profiles table
-- This migration is safe and non-breaking - it only adds new columns with default values

-- Add current_mood column to profiles
-- Default to 'Neutral' so existing users have a valid mood
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS current_mood VARCHAR(50) DEFAULT 'Neutral';

-- Add timestamp for when mood was last updated
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS mood_updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create index for faster mood queries (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_profiles_current_mood ON profiles(current_mood);

-- Update RLS policies (if needed)
-- Ensure users can read other users' moods (for chat, orbit, etc.)
-- Users should already be able to read profiles, but let's be explicit about mood

-- No policy changes needed if profiles are already readable by authenticated users
-- The existing RLS policies should cover mood data access

COMMENT ON COLUMN profiles.current_mood IS 'User current mood state (Happy, Sad, Tired, Irritated, Lonely, Bored, Peaceful, Grateful, Neutral)';
COMMENT ON COLUMN profiles.mood_updated_at IS 'Timestamp of last mood update';
