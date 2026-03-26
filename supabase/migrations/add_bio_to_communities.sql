-- Add bio column to communities table if it doesn't already exist
ALTER TABLE communities 
ADD COLUMN IF NOT EXISTS bio TEXT;

-- Verify
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'communities' AND column_name = 'bio';
