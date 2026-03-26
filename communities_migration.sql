-- Drop table to ensure clean slate with new schema
drop table if exists public.communities cascade;

create table public.communities (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  mood text not null,
  
  -- Creator Details
  created_by uuid references auth.users(id) not null,
  -- We store the username snapshot or you can fetch it via join. 
  -- storing it here satisfies "including who created(username)" for easy access
  created_by_username text, 
  
  -- Stats
  members_count int default 0,
  active_count int default 0,
  avatar_url text,
  
  -- Controls for "Pause Community"
  -- 'active': Normal operation
  -- 'paused': No one can post/delete/interact
  status text default 'active' check (status in ('active', 'paused')),
  
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.communities enable row level security;

-- Policies

-- 1. Everyone can view communities
create policy "Anyone can view communities"
  on public.communities for select
  using (true);

-- 2. Authenticated users can create
create policy "Authenticated users can create communities"
  on public.communities for insert
  with check (auth.role() = 'authenticated');

-- 3. Only the Creator (Owner) can Update (e.g. pause/unpause)
create policy "Owner can update community"
  on public.communities for update
  using (auth.uid() = created_by);

-- 4. Only Owner can Delete
create policy "Owner can delete community"
  on public.communities for delete
  using (auth.uid() = created_by);


-- Example Policy for Linkage (If you have a Community Posts table):
-- This enforces the "If paused no one can post" rule.
/*
create policy "Enforce Community Status on Posts"
  on public.community_posts
  for insert
  with check (
    exists (
      select 1 from public.communities c
      where c.id = community_id
      and c.status = 'active'
    )
  );
*/

-- Seed Data (using dynamic user ID)
insert into public.communities (name, description, mood, created_by, members_count, active_count, status)
select 'Joyful Moments', 'Share your happy moments and celebrate the good times', 'Happy', id, 2847, 124, 'active'
from auth.users order by created_at desc limit 1;

insert into public.communities (name, description, mood, created_by, members_count, active_count, status)
select 'Rest & Recharge', 'For those feeling drained and need support', 'Tired', id, 3256, 201, 'active'
from auth.users order by created_at desc limit 1;
