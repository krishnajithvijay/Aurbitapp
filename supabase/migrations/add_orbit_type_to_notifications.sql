-- Add orbit_type column to notifications table if it doesn't exist
-- Migration: add_orbit_type_to_notifications
-- Created: 2026-01-22

ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS orbit_type TEXT;

-- Verify policies allow insert/select on this column (usually implied by table access)
