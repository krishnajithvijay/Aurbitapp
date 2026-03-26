-- Add explicit support for targeting specific nested replies
-- This column points to the specific comment being replied to, 
-- while parent_id can still point to the root comment for efficient threading/fetching.

ALTER TABLE public.comments 
ADD COLUMN IF NOT EXISTS reply_to_comment_id UUID REFERENCES public.comments(id) ON DELETE SET NULL;

-- Optional: If you want to denormalize the username for easier display
-- ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS reply_to_username TEXT;

-- Update RLS if needed (usually the default insert policy covers new columns)
-- No changes needed to policies if "Authenticated users can create comments" is generic.

-- Index for performance if looking up replies to a specific comment
CREATE INDEX IF NOT EXISTS comments_reply_to_comment_id_idx ON public.comments(reply_to_comment_id);
