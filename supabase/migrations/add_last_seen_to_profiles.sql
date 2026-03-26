-- Add last_seen to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen);

-- Update last_seen function
CREATE OR REPLACE FUNCTION update_last_seen()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET last_seen = NOW()
  WHERE id = auth.uid();
END;
$$;

-- Note: We will call this function from the client app periodically or on activity
