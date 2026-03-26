-- Function to handle reciprocal orbit acceptance securely
-- Migration: create_accept_orbit_request_function
-- Created: 2026-01-22

-- Drop the old function first to allow parameter renaming
DROP FUNCTION IF EXISTS accept_orbit_request(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION accept_orbit_request(
  p_friend_id UUID,          -- The other person (sender of request)
  p_my_orbit_type TEXT,      -- What I call them (e.g. 'inner')
  p_their_orbit_type TEXT    -- What they call me (e.g. 'outer')
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of creator (admin), bypassing RLS
SET search_path = public -- Secure search_path
AS $$
DECLARE
  current_user_id UUID;
BEGIN
  -- Get current user ID
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Insert connection: Me -> Friend
  INSERT INTO user_orbits (user_id, friend_id, orbit_type)
  VALUES (current_user_id, p_friend_id, p_my_orbit_type)
  ON CONFLICT (user_id, friend_id) 
  DO UPDATE SET orbit_type = EXCLUDED.orbit_type; -- Update if exists

  -- 2. Insert connection: Friend -> Me
  INSERT INTO user_orbits (user_id, friend_id, orbit_type)
  VALUES (p_friend_id, current_user_id, p_their_orbit_type)
  ON CONFLICT (user_id, friend_id) 
  DO UPDATE SET orbit_type = EXCLUDED.orbit_type; -- Update if exists

END;
$$;
