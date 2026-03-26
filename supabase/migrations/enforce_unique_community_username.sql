-- Ensure communities have a customizable, unique username handle.
-- Run in Supabase SQL editor if not already applied.

alter table if exists public.communities
  add column if not exists username text;

-- Backfill null usernames so we can enforce NOT NULL safely.
update public.communities
set username = lower(regexp_replace(name, '[^a-zA-Z0-9_]', '_', 'g'))
where username is null or btrim(username) = '';

alter table if exists public.communities
  alter column username set not null;

-- Enforce handle format.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'communities_username_format_check'
  ) then
    alter table public.communities
      add constraint communities_username_format_check
      check (username ~ '^[a-z0-9_]{3,25}$');
  end if;
end$$;

-- Case-insensitive uniqueness for c/<username>.
create unique index if not exists communities_username_unique_idx
  on public.communities (lower(username));
