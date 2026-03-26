-- Create User Blocks Table
CREATE TABLE IF NOT EXISTS public.user_blocks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    blocker_id UUID REFERENCES auth.users(id) NOT NULL,
    blocked_id UUID REFERENCES public.profiles(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_block UNIQUE (blocker_id, blocked_id)
);

-- Create Reports Table
-- First create enum if it doesn't exist (handling potential re-run)
DO $$ BEGIN
    CREATE TYPE report_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id UUID REFERENCES auth.users(id) NOT NULL,
    reported_id UUID REFERENCES public.profiles(id) NOT NULL,
    reason TEXT NOT NULL,
    status report_status DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Policies for Blocks
DO $$ BEGIN
    CREATE POLICY "Users can view their own blocks" ON public.user_blocks
        FOR SELECT USING (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can create blocks" ON public.user_blocks
        FOR INSERT WITH CHECK (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can delete their blocks" ON public.user_blocks
        FOR DELETE USING (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Policies for Reports
DO $$ BEGIN
    CREATE POLICY "Users can insert reports" ON public.reports
        FOR INSERT WITH CHECK (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Admin View for Block Details
CREATE OR REPLACE VIEW public.admin_blocks_view AS
SELECT 
    ub.id as block_id,
    ub.created_at as blocked_at,
    -- Blocker Details
    ub.blocker_id,
    blocker_p.username as blocker_name,
    blocker_u.email as blocker_email,
    -- Blocked User Details
    ub.blocked_id,
    blocked_p.username as blocked_name,
    blocked_u.email as blocked_email
FROM public.user_blocks ub
LEFT JOIN public.profiles blocker_p ON ub.blocker_id = blocker_p.id
LEFT JOIN auth.users blocker_u ON ub.blocker_id = blocker_u.id
LEFT JOIN public.profiles blocked_p ON ub.blocked_id = blocked_p.id
LEFT JOIN auth.users blocked_u ON ub.blocked_id = blocked_u.id;

-- Admin View for Reports (NEW)
-- This view shows details of the reporter, the reported user, reason, status, and time.
CREATE OR REPLACE VIEW public.admin_reports_view AS
SELECT 
    r.id as report_id,
    r.created_at as reported_at,
    r.reason,
    r.status,
    -- Reporter Details (Who Sent the Report)
    r.reporter_id,
    reporter_p.username as reporter_name,
    reporter_u.email as reporter_email,
    -- Reported User Details (Who was Reported)
    r.reported_id,
    reported_p.username as reported_name,
    reported_u.email as reported_email
FROM public.reports r
LEFT JOIN public.profiles reporter_p ON r.reporter_id = reporter_p.id
LEFT JOIN auth.users reporter_u ON r.reporter_id = reporter_u.id
LEFT JOIN public.profiles reported_p ON r.reported_id = reported_p.id
LEFT JOIN auth.users reported_u ON r.reported_id = reported_u.id;
