-- Create Posts table
create table if not exists public.posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  content text not null,
  privacy_level text not null check (privacy_level in ('private', 'inner_orbit', 'outer_orbit', 'anonymous_public', 'inner', 'outer', 'anonymous')), -- Allow flexible enums for now
  mood text,
  is_anonymous boolean default false,
  expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.posts enable row level security;

-- Policies
-- 1. Users can insert their own posts
create policy "Users can create posts"
  on public.posts for insert
  with check (auth.uid() = user_id);

-- 2. Reading posts (Complex logic simplified for now)
-- Owners can always see their posts
create policy "Users can see own posts"
  on public.posts for select
  using (auth.uid() = user_id);

-- Anonymous Public posts are visible to everyone
create policy "Public posts are visible to everyone"
  on public.posts for select
  using (privacy_level = 'anonymous_public' or privacy_level = 'anonymous');

-- Inner Orbit / Outer Orbit logic requires 'relationships' table which we might not have standardized yet.
-- For now, allow viewing if authenticated (simplification to get UI working), 
-- OR strictly enforce if we had the social graph.
-- Let's make a broad "Authenticated users can see non-private posts" policy for dev, 
-- refining later when Friendships/Orbits are implemented.
create policy "Authenticated users can see orbit posts"
  on public.posts for select
  using (auth.role() = 'authenticated' and privacy_level != 'private');

-- Add realtime
alter publication supabase_realtime add table public.posts;
