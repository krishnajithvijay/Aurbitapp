-- Create a table to track which layer (inner vs outer) a friend is in for a given user
CREATE TABLE public.orbit_friends (
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  friend_id UUID REFERENCES public.profiles(id) NOT NULL,
  orbit_layer TEXT CHECK (orbit_layer IN ('inner', 'outer')) NOT NULL DEFAULT 'outer',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (user_id, friend_id)
);

-- Enable Row Level Security
ALTER TABLE public.orbit_friends ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own orbit." 
  ON public.orbit_friends 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update their own orbit." 
  ON public.orbit_friends 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own orbit." 
  ON public.orbit_friends 
  FOR UPDATE 
  USING (auth.uid() = user_id);
  
-- Optional: If you want upsert to work smoothly with update policy
CREATE POLICY "Users can upsert orbit friends"
    ON public.orbit_friends
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
