import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const communitiesRouter = Router();

// List communities
communitiesRouter.get('/', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('communities')
      .select('*')
      .order('member_count', { ascending: false });

    if (error) throw error;

    // Check which ones user has joined
    const { data: memberships } = await supabaseAdmin
      .from('community_members')
      .select('community_id')
      .eq('user_id', req.user!.id);

    const joinedIds = new Set((memberships ?? []).map((m: { community_id: string }) => m.community_id));

    res.json((data ?? []).map((c: { id: string }) => ({ ...c, is_joined: joinedIds.has(c.id) })));
  } catch {
    res.status(500).json({ error: 'Failed to fetch communities' });
  }
});

// Create community
communitiesRouter.post('/', requireAuth, async (req: AuthRequest, res) => {
  const { name, description, is_private, tags } = req.body as {
    name: string;
    description?: string;
    is_private?: boolean;
    tags?: string[];
  };

  if (!name?.trim()) {
    res.status(400).json({ error: 'Community name is required' });
    return;
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('communities')
      .insert({
        name: name.trim(),
        description: description?.trim() ?? null,
        created_by: req.user!.id,
        is_private: is_private ?? false,
        tags: tags ?? [],
        member_count: 1,
        post_count: 0,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;

    // Auto-join creator as admin
    await supabaseAdmin.from('community_members').insert({
      community_id: data.id,
      user_id: req.user!.id,
      role: 'admin',
      joined_at: new Date().toISOString(),
    });

    res.status(201).json({ ...data, is_joined: true });
  } catch {
    res.status(500).json({ error: 'Failed to create community' });
  }
});

// Join community
communitiesRouter.post('/:id/join', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data: existing } = await supabaseAdmin
      .from('community_members')
      .select('id')
      .match({ community_id: req.params.id, user_id: req.user!.id })
      .single();

    if (existing) {
      res.status(409).json({ error: 'Already a member' });
      return;
    }

    await supabaseAdmin.from('community_members').insert({
      community_id: req.params.id,
      user_id: req.user!.id,
      role: 'member',
      joined_at: new Date().toISOString(),
    });

    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to join community' });
  }
});

// Leave community
communitiesRouter.post('/:id/leave', requireAuth, async (req: AuthRequest, res) => {
  try {
    await supabaseAdmin
      .from('community_members')
      .delete()
      .match({ community_id: req.params.id, user_id: req.user!.id });

    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to leave community' });
  }
});

// Get community posts
communitiesRouter.get('/:id/posts', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('posts')
      .select('*, author:profiles!user_id(*)')
      .eq('community_id', req.params.id)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data ?? []);
  } catch {
    res.status(500).json({ error: 'Failed to fetch community posts' });
  }
});
