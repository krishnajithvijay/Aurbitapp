-- User Activity Tracking Migration
-- This enables showing "active now" status in chat and communities

-- Create user_activity table to track when users were last active
CREATE TABLE IF NOT EXISTS public.user_activity (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.user_activity ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DO $$ 
BEGIN
    -- Users can view all activity (to see who's online)
    IF NOT EXISTS (SELECT FROM pg_policies WHERE policyname = 'Anyone can view user activity' AND tablename = 'user_activity') THEN
        CREATE POLICY "Anyone can view user activity" 
            ON public.user_activity FOR SELECT 
            USING (true);
    END IF;

    -- Users can insert their own activity
    IF NOT EXISTS (SELECT FROM pg_policies WHERE policyname = 'Users can insert their own activity' AND tablename = 'user_activity') THEN
        CREATE POLICY "Users can insert their own activity" 
            ON public.user_activity FOR INSERT 
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Users can update their own activity
    IF NOT EXISTS (SELECT FROM pg_policies WHERE policyname = 'Users can update their own activity' AND tablename = 'user_activity') THEN
        CREATE POLICY "Users can update their own activity"
            ON public.user_activity FOR UPDATE
            USING (auth.uid() = user_id);
    END IF;
END $$;

-- Create index for performance
CREATE INDEX IF NOT EXISTS user_activity_last_active_idx ON public.user_activity(last_active_at DESC);

-- Function to update user activity (call from app)
CREATE OR REPLACE FUNCTION public.update_user_activity()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_activity (user_id, last_active_at, updated_at)
    VALUES (auth.uid(), NOW(), NOW())
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        last_active_at = NOW(),
        updated_at = NOW();
END;
$$;

-- Function to check if user is currently active (active within last 5 minutes)
CREATE OR REPLACE FUNCTION public.is_user_active(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    last_seen TIMESTAMP WITH TIME ZONE;
BEGIN
    SELECT last_active_at INTO last_seen
    FROM public.user_activity
    WHERE user_id = check_user_id;
    
    IF last_seen IS NULL THEN
        RETURN false;
    END IF;
    
    -- User is active if they were seen within last 5 minutes
    RETURN (NOW() - last_seen) < INTERVAL '5 minutes';
END;
$$;

-- Function to get count of active users in a community
CREATE OR REPLACE FUNCTION public.get_active_community_members(community_id_param UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    active_count INTEGER;
BEGIN
    SELECT COUNT(DISTINCT cm.user_id) INTO active_count
    FROM public.community_members cm
    INNER JOIN public.user_activity ua ON cm.user_id = ua.user_id
    WHERE cm.community_id = community_id_param
    AND (NOW() - ua.last_active_at) < INTERVAL '5 minutes';
    
    RETURN COALESCE(active_count, 0);
END;
$$;

-- Function to get active status for multiple users (batch query)
CREATE OR REPLACE FUNCTION public.get_users_activity_status(user_ids UUID[])
RETURNS TABLE (
    user_id UUID,
    is_active BOOLEAN,
    last_active_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        CASE 
            WHEN ua.last_active_at IS NOT NULL 
            AND (NOW() - ua.last_active_at) < INTERVAL '5 minutes' 
            THEN true 
            ELSE false 
        END as is_active,
        ua.last_active_at
    FROM unnest(user_ids) u(id)
    LEFT JOIN public.user_activity ua ON u.id = ua.user_id;
END;
$$;

-- Enable Realtime for user_activity table (optional - for live updates)
ALTER PUBLICATION supabase_realtime ADD TABLE user_activity;

COMMENT ON TABLE public.user_activity IS 'Tracks user activity for online status indicators';
COMMENT ON FUNCTION public.update_user_activity() IS 'Updates the current user last active timestamp';
COMMENT ON FUNCTION public.is_user_active(UUID) IS 'Returns true if user was active within last 5 minutes';
COMMENT ON FUNCTION public.get_active_community_members(UUID) IS 'Returns count of active members in a community';
