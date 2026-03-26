-- 1. Enable the required extension for HTTP requests
create extension if not exists "pg_net" with schema "extensions";

-- 2. Define the function to send push notifications
create or replace function notify_push()
returns trigger
security definer
as $$
declare
  -- You can verify these values in your project settings
  project_url text := 'https://henxsgquexgxvfwngjet.supabase.co';
  anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlbnhzZ3F1ZXhneHZmd25namV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjg4NTIsImV4cCI6MjA4NDUwNDg1Mn0.qhovSln6868wGsK-7jqM9D-C2133_Gcpj-E1uX4QHg0';
begin
  -- Call the Edge Function using pg_net
  perform
    net.http_post(
      url := project_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || anon_key
      ),
      body := jsonb_build_object('record', row_to_json(NEW))
    );

  return NEW;
end;
$$ language plpgsql;

-- 3. Re-create the trigger
drop trigger if exists push_notification_trigger on notifications;

create trigger push_notification_trigger
after insert on notifications
for each row
execute function notify_push();
