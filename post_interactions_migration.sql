-- Create a table to track user reactions to posts
CREATE TABLE public.post_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL CHECK (reaction_type IN ('relate', 'not_alone')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, post_id, reaction_type)
);

-- Enable RLS
ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view all reactions" 
ON public.post_reactions FOR SELECT 
USING (true);

CREATE POLICY "Users can insert their own reactions" 
ON public.post_reactions FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reactions" 
ON public.post_reactions FOR DELETE 
USING (auth.uid() = user_id);

-- Optional: Add count columns to posts table if we want to cache counts (performance optimization)
-- For now, we can count directly or use a view, but adding columns is often easier for frontend.
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS relate_count INTEGER DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS not_alone_count INTEGER DEFAULT 0;

-- Function to update counts on insert/delete
CREATE OR REPLACE FUNCTION public.handle_reaction_counters() 
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.reaction_type = 'relate') THEN
      UPDATE public.posts SET relate_count = relate_count + 1 WHERE id = NEW.post_id;
    ELSIF (NEW.reaction_type = 'not_alone') THEN
      UPDATE public.posts SET not_alone_count = not_alone_count + 1 WHERE id = NEW.post_id;
    END IF;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.reaction_type = 'relate') THEN
      UPDATE public.posts SET relate_count = relate_count - 1 WHERE id = OLD.post_id;
    ELSIF (OLD.reaction_type = 'not_alone') THEN
      UPDATE public.posts SET not_alone_count = not_alone_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for reactions
CREATE TRIGGER on_reaction_change
AFTER INSERT OR DELETE ON public.post_reactions
FOR EACH ROW EXECUTE FUNCTION public.handle_reaction_counters();

-- Enable Realtime for reactions so UI updates instantly
alter publication supabase_realtime add table public.posts;
alter publication supabase_realtime add table public.post_reactions;
