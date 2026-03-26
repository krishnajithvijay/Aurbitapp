-- Ensure profiles table has fcm_token column
alter table public.profiles 
add column if not exists fcm_token text;

-- Ensure users can update their own fcm_token
-- Note: This is a broad policy. If you have specific update policies, 
-- you might need to adjust them or rely on them. 
-- Usually "Users can update own profile" covers all columns.
-- We will just make sure the column exists.
