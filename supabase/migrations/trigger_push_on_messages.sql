-- Trigger to send push notifications for new messages in chat
create trigger push_message_trigger
after insert on public.messages
for each row
execute function notify_push();
