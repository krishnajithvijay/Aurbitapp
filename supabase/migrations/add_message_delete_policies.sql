-- Migration: Add RLS policies for message deletion

-- Drop existing policies if they exist (ignore errors if they don't)
DROP POLICY IF EXISTS "Users can delete their own messages" ON messages;
DROP POLICY IF EXISTS "Users can delete messages they received" ON messages;
DROP POLICY IF EXISTS "Users can delete conversation messages" ON messages;

-- Create policy allowing users to delete messages they sent or received
CREATE POLICY "Users can delete conversation messages"
ON messages FOR DELETE
USING (
    auth.uid() = sender_id OR 
    auth.uid() = receiver_id
);

-- Verify it was created
SELECT policyname, tablename, cmd 
FROM pg_policies 
WHERE tablename = 'messages' AND cmd = 'DELETE';
