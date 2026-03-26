-- Create mood_logs table for tracking mood history
-- Migration: create_mood_logs_table
-- Created: 2026-01-22

CREATE TABLE IF NOT EXISTS mood_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mood TEXT NOT NULL,
  note TEXT
);

-- Ensure created_at exists (safeguard for existing tables)
ALTER TABLE mood_logs 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_mood_logs_user_id ON mood_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_mood_logs_created_at ON mood_logs(created_at DESC);

-- RLS
ALTER TABLE mood_logs ENABLE ROW LEVEL SECURITY;

-- Clear policies to avoid duplicates on re-run
DROP POLICY IF EXISTS "Users can view their own mood logs" ON mood_logs;
DROP POLICY IF EXISTS "Authenticated users can view mood logs" ON mood_logs;
DROP POLICY IF EXISTS "Users can add their own mood logs" ON mood_logs;

-- Users can view their own mood logs
CREATE POLICY "Users can view their own mood logs"
  ON mood_logs FOR SELECT
  USING (auth.uid() = user_id);

-- Friends/Authenticated users can view mood logs
CREATE POLICY "Authenticated users can view mood logs"
  ON mood_logs FOR SELECT
  USING (auth.role() = 'authenticated');

-- Users can insert their own mood logs
CREATE POLICY "Users can add their own mood logs"
  ON mood_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);
