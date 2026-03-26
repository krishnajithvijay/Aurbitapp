-- Create Comments table
create table if not exists public.comments (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.posts(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  parent_id uuid references public.comments(id) on delete cascade, -- For nested replies
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.comments enable row level security;

-- Policies
create policy "Anyone can view comments"
  on public.comments for select
  using (true);

create policy "Authenticated users can create comments"
  on public.comments for insert
  with check (auth.role() = 'authenticated');

create policy "Users can delete their own comments"
  on public.comments for delete
  using (auth.uid() = user_id);

-- Enable Realtime
alter publication supabase_realtime add table public.comments;
