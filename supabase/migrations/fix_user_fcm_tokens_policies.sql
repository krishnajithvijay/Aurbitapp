-- Safely align the user_fcm_tokens table
-- 1. Grant permissions
grant all on table public.user_fcm_tokens to service_role;
grant all on table public.user_fcm_tokens to authenticated;

-- 2. Drop existing policies to prevent "already exists" errors
drop policy if exists "Users can view their own tokens" on public.user_fcm_tokens;
drop policy if exists "Users can insert/update their own tokens" on public.user_fcm_tokens;
drop policy if exists "Users can update their own tokens" on public.user_fcm_tokens;
drop policy if exists "Users can delete their own tokens" on public.user_fcm_tokens;

-- 3. Re-create policies to ensure they are correctly aligned
create policy "Users can view their own tokens"
on public.user_fcm_tokens for select
using (auth.uid() = user_id);

create policy "Users can insert/update their own tokens"
on public.user_fcm_tokens for insert
with check (auth.uid() = user_id);

create policy "Users can update their own tokens"
on public.user_fcm_tokens for update
using (auth.uid() = user_id);

create policy "Users can delete their own tokens"
on public.user_fcm_tokens for delete
using (auth.uid() = user_id);
