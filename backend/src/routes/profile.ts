import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const profileRouter = Router();

// Search users — must be registered before /:username to avoid route shadowing
profileRouter.get('/search', requireAuth, async (req: AuthRequest, res) => {
  const query = req.query.q as string;

  if (!query?.trim()) {
    res.status(400).json({ error: 'Query is required' });
    return;
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .or(`username.ilike.%${query}%,display_name.ilike.%${query}%`)
      .neq('id', req.user!.id)
      .limit(20);

    if (error) throw error;
    res.json(data ?? []);
  } catch {
    res.status(500).json({ error: 'Failed to search users' });
  }
});

// Update own profile — must be registered before /:username to avoid route shadowing
profileRouter.patch('/me', requireAuth, async (req: AuthRequest, res) => {
  const { display_name, bio, avatar_url, username } = req.body as {
    display_name?: string;
    bio?: string;
    avatar_url?: string;
    username?: string;
  };

  const updates: Record<string, string> = {
    updated_at: new Date().toISOString(),
  };

  if (display_name !== undefined) updates.display_name = display_name;
  if (bio !== undefined) updates.bio = bio;
  if (avatar_url !== undefined) updates.avatar_url = avatar_url;
  if (username !== undefined) updates.username = username.toLowerCase().replace(/[^a-z0-9_]/g, '');

  try {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .update(updates)
      .eq('id', req.user!.id)
      .select()
      .single();

    if (error) throw error;
    res.json(data);
  } catch {
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// Get profile by username
profileRouter.get('/:username', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('username', req.params.username)
      .single();

    if (error || !data) {
      res.status(404).json({ error: 'Profile not found' });
      return;
    }

    res.json(data);
  } catch {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// Get user's posts
profileRouter.get('/:username/posts', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('username', req.params.username)
      .single();

    if (!profile) {
      res.status(404).json({ error: 'Profile not found' });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('posts')
      .select('*, author:profiles!user_id(*)')
      .eq('user_id', profile.id)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data ?? []);
  } catch {
    res.status(500).json({ error: "Failed to fetch user's posts" });
  }
});
