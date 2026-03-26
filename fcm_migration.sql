-- Migration for FCM Tokens

-- Create user_fcm_tokens table
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type TEXT CHECK (device_type IN ('android', 'ios', 'web', 'other')),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one token is only stored once per user, but a user can have multiple distinct tokens (devices)
    UNIQUE(user_id, token)
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON user_fcm_tokens(user_id);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert their own tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON user_fcm_tokens;

-- Policies
CREATE POLICY "Users can view their own tokens"
    ON user_fcm_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tokens"
    ON user_fcm_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tokens"
    ON user_fcm_tokens FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tokens"
    ON user_fcm_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- Function to update last_updated timestamp
CREATE OR REPLACE FUNCTION update_fcm_token_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger to avoid conflicts
DROP TRIGGER IF EXISTS update_fcm_token_timestamp ON user_fcm_tokens;

CREATE TRIGGER update_fcm_token_timestamp
    BEFORE UPDATE ON user_fcm_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_fcm_token_timestamp();
