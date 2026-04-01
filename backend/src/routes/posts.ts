import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const postsRouter = Router();

// Get feed posts (paginated)
postsRouter.get('/feed', requireAuth, async (req: AuthRequest, res) => {
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 20;
  const from = (page - 1) * limit;

  try {
    const { data, error, count } = await supabaseAdmin
      .from('posts')
      .select('*, author:profiles!user_id(*)', { count: 'exact' })
      .is('community_id', null)
      .order('created_at', { ascending: false })
      .range(from, from + limit - 1);

    if (error) throw error;

    // Check liked status
    const { data: likes } = await supabaseAdmin
      .from('post_likes')
      .select('post_id')
      .eq('user_id', req.user!.id)
      .in('post_id', (data ?? []).map((p: { id: string }) => p.id));

    const likedIds = new Set((likes ?? []).map((l: { post_id: string }) => l.post_id));
    const postsWithLikes = (data ?? []).map((p: { id: string }) => ({
      ...p,
      is_liked: likedIds.has(p.id),
    }));

    res.json({
      data: postsWithLikes,
      total: count ?? 0,
      page,
      limit,
      hasMore: (count ?? 0) > from + limit,
    });
  } catch {
    res.status(500).json({ error: 'Failed to fetch feed' });
  }
});

// Create post
postsRouter.post('/', requireAuth, async (req: AuthRequest, res) => {
  const { content, community_id, media_url, media_type } = req.body as {
    content: string;
    community_id?: string;
    media_url?: string;
    media_type?: string;
  };

  if (!content?.trim()) {
    res.status(400).json({ error: 'Content is required' });
    return;
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('posts')
      .insert({
        user_id: req.user!.id,
        content: content.trim(),
        community_id: community_id ?? null,
        media_url: media_url ?? null,
        media_type: media_type ?? null,
        created_at: new Date().toISOString(),
      })
      .select('*, author:profiles!user_id(*)')
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch {
    res.status(500).json({ error: 'Failed to create post' });
  }
});

// Delete post
postsRouter.delete('/:id', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { error } = await supabaseAdmin
      .from('posts')
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id); // Only owner can delete

    if (error) throw error;
    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to delete post' });
  }
});

// Like/unlike post
postsRouter.post('/:id/like', requireAuth, async (req: AuthRequest, res) => {
  const postId = req.params.id;
  const userId = req.user!.id;

  try {
    const { data: existing } = await supabaseAdmin
      .from('post_likes')
      .select('id')
      .match({ post_id: postId, user_id: userId })
      .single();

    if (existing) {
      await supabaseAdmin.from('post_likes').delete().match({ post_id: postId, user_id: userId });
      res.json({ liked: false });
    } else {
      await supabaseAdmin.from('post_likes').insert({ post_id: postId, user_id: userId });
      res.json({ liked: true });
    }
  } catch {
    res.status(500).json({ error: 'Failed to toggle like' });
  }
});

// Get post comments
postsRouter.get('/:id/comments', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('post_comments')
      .select('*, author:profiles!user_id(*)')
      .eq('post_id', req.params.id)
      .order('created_at', { ascending: true });

    if (error) throw error;
    res.json(data ?? []);
  } catch {
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
});

// Add comment
postsRouter.post('/:id/comments', requireAuth, async (req: AuthRequest, res) => {
  const { content, reply_to_id } = req.body as { content: string; reply_to_id?: string };

  if (!content?.trim()) {
    res.status(400).json({ error: 'Content is required' });
    return;
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('post_comments')
      .insert({
        post_id: req.params.id,
        user_id: req.user!.id,
        content: content.trim(),
        reply_to_id: reply_to_id ?? null,
        created_at: new Date().toISOString(),
      })
      .select('*, author:profiles!user_id(*)')
      .single();

    if (error) throw error;

    // Create notification for post author
    const { data: post } = await supabaseAdmin
      .from('posts')
      .select('user_id')
      .eq('id', req.params.id)
      .single();

    if (post && post.user_id !== req.user!.id) {
      await supabaseAdmin.from('notifications').insert({
        user_id: post.user_id,
        type: 'comment',
        actor_id: req.user!.id,
        title: 'New comment',
        body: content.trim().slice(0, 100),
        reference_id: req.params.id,
        is_read: false,
        created_at: new Date().toISOString(),
      });
    }

    res.status(201).json(data);
  } catch {
    res.status(500).json({ error: 'Failed to add comment' });
  }
});
