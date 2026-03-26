-- Trigger for Push Notifications
drop trigger if exists push_notification_trigger on notifications;

create trigger push_notification_trigger
after insert on notifications
for each row
execute function notify_push();
