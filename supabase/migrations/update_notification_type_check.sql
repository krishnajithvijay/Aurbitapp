-- Drop the constraint if it exists (so we can update it or recreate it without error)
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add the updated constraint including new types
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
CHECK (type IN ('reaction', 'comment', 'reply', 'orbit_request', 'orbit_accept', 'message', 'trending_post', 'community_new_post'));
