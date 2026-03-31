import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const notificationsRouter = Router();

// Get notifications
notificationsRouter.get('/', requireAuth, async (req: AuthRequest, res) => {
  const limit = parseInt(req.query.limit as string) || 50;

  try {
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .select('*, actor:profiles!actor_id(*)')
      .eq('user_id', req.user!.id)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) throw error;
    res.json(data ?? []);
  } catch {
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
});

// Mark all as read
notificationsRouter.post('/read-all', requireAuth, async (req: AuthRequest, res) => {
  try {
    await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', req.user!.id)
      .eq('is_read', false);

    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to mark notifications as read' });
  }
});

// Mark single notification as read
notificationsRouter.post('/:id/read', requireAuth, async (req: AuthRequest, res) => {
  try {
    await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id);

    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to mark notification as read' });
  }
});

// Get unread count
notificationsRouter.get('/unread-count', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { count, error } = await supabaseAdmin
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', req.user!.id)
      .eq('is_read', false);

    if (error) throw error;
    res.json({ count: count ?? 0 });
  } catch {
    res.status(500).json({ error: 'Failed to fetch unread count' });
  }
});

// Save FCM token
notificationsRouter.post('/fcm-token', requireAuth, async (req: AuthRequest, res) => {
  const { token, platform } = req.body as { token: string; platform: string };

  if (!token) {
    res.status(400).json({ error: 'Token is required' });
    return;
  }

  try {
    await supabaseAdmin
      .from('fcm_tokens')
      .upsert({
        user_id: req.user!.id,
        token,
        platform: platform ?? 'web',
        updated_at: new Date().toISOString(),
      }, { onConflict: 'token' });

    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to save FCM token' });
  }
});
