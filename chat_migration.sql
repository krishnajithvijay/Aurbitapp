-- Create messages table for 1-1 chat
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES auth.users(id) NOT NULL,
    receiver_id UUID REFERENCES public.profiles(id) NOT NULL,
    content TEXT NOT NULL,
    reply_to_id UUID REFERENCES public.messages(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_read BOOLEAN DEFAULT false,
    
    -- Constraint to prevent self-chat if desired, but maybe allowed for notes
    CONSTRAINT messages_sender_receiver_check CHECK (sender_id <> receiver_id)
);

-- Enable RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Policies
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_policies WHERE policyname = 'Users can view messages they sent or received' AND tablename = 'messages') THEN
        CREATE POLICY "Users can view messages they sent or received" 
            ON public.messages FOR SELECT 
            USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
    END IF;

    IF NOT EXISTS (SELECT FROM pg_policies WHERE policyname = 'Users can insert messages they send' AND tablename = 'messages') THEN
        CREATE POLICY "Users can insert messages they send" 
            ON public.messages FOR INSERT 
            WITH CHECK (auth.uid() = sender_id);
    END IF;

    IF NOT EXISTS (SELECT FROM pg_policies WHERE policyname = 'Users can update their own messages' AND tablename = 'messages') THEN
        CREATE POLICY "Users can update their own messages"
            ON public.messages FOR UPDATE
            USING (auth.uid() = sender_id);
    END IF;
END $$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS messages_sender_receiver_idx ON public.messages(sender_id, receiver_id);
CREATE INDEX IF NOT EXISTS messages_receiver_sender_idx ON public.messages(receiver_id, sender_id);
CREATE INDEX IF NOT EXISTS messages_created_at_idx ON public.messages(created_at DESC);

-- Enable Realtime for messages table
-- This is critical for the chat to update instantly!
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
COMMIT;
-- Note: The above usually exists by default, but we need to ensure 'messages' is included. 
-- Often 'FOR ALL TABLES' is the default. If you have a custom publication:
-- ALTER PUBLICATION supabase_realtime ADD TABLE messages;
-- But the standard way to ensure it's on for a specific table if not 'ALL TABLES' is:
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
