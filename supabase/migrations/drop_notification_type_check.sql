-- Drop the restrictive constraint to allow new types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Optional: If you really want enforcement, verify your data first.
-- For now, we will rely on application logic to handle types.
-- If you want to re-add it, you must ensure ALL existing rows have valid types.
