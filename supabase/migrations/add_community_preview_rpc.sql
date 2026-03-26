-- Function to fetch avatar previews for specific communities
create or replace function get_community_avatars(community_ids uuid[])
returns table (
  community_id uuid,
  avatar_urls text[]
)
language plpgsql
security definer
as $$
begin
  return query
  select 
    c.id as community_id,
    coalesce(
      (
        select array_agg(sub.avatar_url)
        from (
          select p.avatar_url
          from community_members cm
          join profiles p on p.id = cm.user_id
          where cm.community_id = c.id
          and p.avatar_url is not null
          limit 4
        ) sub
      ),
      array[]::text[]
    ) as avatar_urls
  from communities c
  where c.id = any(community_ids);
end;
$$;
