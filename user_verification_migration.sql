-- Migration for User Verification Blue Tick Feature
-- Adds verification status to user profiles

-- 1. Add is_verified column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

-- 2. Add verification_date column to track when user was verified
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;

-- 3. Add verification_type column (optional - for different verification tiers)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS verification_type TEXT CHECK (verification_type IN ('standard', 'premium', 'official'));

-- 4. Create verification_requests table for users to request verification
CREATE TABLE IF NOT EXISTS verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES profiles(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    
    -- User can only have one active request
    UNIQUE(user_id)
);

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_verified ON profiles(is_verified);
CREATE INDEX IF NOT EXISTS idx_verification_requests_user ON verification_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_requests_status ON verification_requests(status);

-- 6. Enable Row Level Security
ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies for verification_requests

-- Users can view their own verification requests
CREATE POLICY "Users can view their own verification requests"
    ON verification_requests
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can create their own verification requests
CREATE POLICY "Users can create verification requests"
    ON verification_requests
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own pending requests (cancel)
CREATE POLICY "Users can update their own requests"
    ON verification_requests
    FOR UPDATE
    USING (auth.uid() = user_id AND status = 'pending');

-- 7. Function to grant verification to a user
CREATE OR REPLACE FUNCTION grant_verification(
    p_user_id UUID,
    p_verification_type TEXT DEFAULT 'standard'
)
RETURNS void AS $$
BEGIN
    -- Update profile to verified
    UPDATE profiles
    SET 
        is_verified = TRUE,
        verified_at = NOW(),
        verification_type = p_verification_type
    WHERE id = p_user_id;
    
    -- Update verification request if exists
    UPDATE verification_requests
    SET 
        status = 'approved',
        reviewed_at = NOW()
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Function to revoke verification from a user
CREATE OR REPLACE FUNCTION revoke_verification(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE profiles
    SET 
        is_verified = FALSE,
        verified_at = NULL,
        verification_type = NULL
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 9. Function to check if user is verified
CREATE OR REPLACE FUNCTION is_user_verified(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    verified BOOLEAN;
BEGIN
    SELECT is_verified INTO verified
    FROM profiles
    WHERE id = p_user_id;
    
    RETURN COALESCE(verified, FALSE);
END;
$$ LANGUAGE plpgsql STABLE;

-- 10. Function to get verified users count
CREATE OR REPLACE FUNCTION get_verified_users_count()
RETURNS INTEGER AS $$
DECLARE
    count INTEGER;
BEGIN
    SELECT COUNT(*) INTO count
    FROM profiles
    WHERE is_verified = TRUE;
    
    RETURN count;
END;
$$ LANGUAGE plpgsql STABLE;

-- 11. Optional: Seed some verified users for testing
-- Uncomment and modify as needed
/*
UPDATE profiles
SET is_verified = TRUE, verified_at = NOW(), verification_type = 'standard'
WHERE id IN (
    -- Add specific user IDs here
    SELECT id FROM profiles ORDER BY created_at LIMIT 5
);
*/

-- 12. Comments
COMMENT ON COLUMN profiles.is_verified IS 'Indicates if the user has a verified blue tick badge';
COMMENT ON COLUMN profiles.verified_at IS 'Timestamp when the user was verified';
COMMENT ON COLUMN profiles.verification_type IS 'Type of verification: standard, premium, or official';
COMMENT ON TABLE verification_requests IS 'Stores user requests for verification badges';
