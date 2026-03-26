-- Fix foreign key constraints for messages table to allow deletion of users
-- The error indicates that deleting a profile is blocked because messages reference it without CASCADE.

-- 1. Receiver Foreign Key
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_receiver_id_fkey;

ALTER TABLE messages
ADD CONSTRAINT messages_receiver_id_fkey
FOREIGN KEY (receiver_id)
REFERENCES profiles(id)
ON DELETE CASCADE;

-- 2. Sender Foreign Key (Good practice to update this too)
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;

ALTER TABLE messages
ADD CONSTRAINT messages_sender_id_fkey
FOREIGN KEY (sender_id)
REFERENCES profiles(id)
ON DELETE CASCADE;
