-- Function to safely mark all messages from a specific user as read
-- Used to fix "stuck" unread counts atomically on the server
create or replace function mark_conversation_read(target_sender_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update messages
  set is_read = true
  where sender_id = target_sender_id
  and receiver_id = auth.uid() -- Only update messages sent TO the current user
  and is_read = false;         -- Only update if currently unread
end;
$$;

-- Optional: A function to get accurate unread counts directly (avoids client-side math errors)
create or replace function get_unread_count(target_sender_id uuid)
returns bigint
language sql
security definer
as $$
  select count(*)
  from messages
  where sender_id = target_sender_id
  and receiver_id = auth.uid()
  and is_read = false;
$$;
