-- Comprehensive Fix for Profiles Update Issue

-- 1. Ensure fcm_token column exists (Idempotent)
alter table public.profiles 
add column if not exists fcm_token text;

-- 2. Ensure RLS is enabled
alter table public.profiles enable row level security;

-- 3. FIX: Create/Replace the policy allowing users to UPDATE their OWN profile
drop policy if exists "Users can update own profile" on public.profiles;

create policy "Users can update own profile"
on public.profiles for update
using ( auth.uid() = id );

-- 4. FIX: Grant necessary permissions
grant update on table public.profiles to authenticated;
grant select on table public.profiles to authenticated;

-- 5. Optional verification: Check if trigger exists (informational only)
-- select tgname from pg_trigger where tgrelid = 'public.profiles'::regclass;
