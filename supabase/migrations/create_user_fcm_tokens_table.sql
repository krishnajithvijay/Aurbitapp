-- Create user_fcm_tokens table if it doesn't exist
create table if not exists public.user_fcm_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  token text not null,
  device_type text default 'android',
  last_updated timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  -- Ensure unique pair of user_id and token
  unique (user_id, token)
);

-- Enable RLS
alter table public.user_fcm_tokens enable row level security;

-- Policies
create policy "Users can view their own tokens"
on public.user_fcm_tokens for select
using (auth.uid() = user_id);

create policy "Users can insert/update their own tokens"
on public.user_fcm_tokens for insert
with check (auth.uid() = user_id);

-- Depending on your setup, you might need a separate update policy or just rely on ON CONFLICT in insert
create policy "Users can update their own tokens"
on public.user_fcm_tokens for update
using (auth.uid() = user_id);

create policy "Users can delete their own tokens"
on public.user_fcm_tokens for delete
using (auth.uid() = user_id);

-- Grand access to authenticated users
grant all on public.user_fcm_tokens to authenticated;
grant all on public.user_fcm_tokens to service_role;
