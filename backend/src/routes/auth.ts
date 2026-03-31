import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const authRouter = Router();

// Get current user profile
authRouter.get('/me', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', req.user!.id)
      .single();

    if (error) {
      res.status(404).json({ error: 'Profile not found' });
      return;
    }

    res.json(data);
  } catch {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// Update online status
authRouter.post('/status', requireAuth, async (req: AuthRequest, res) => {
  const { is_online } = req.body as { is_online: boolean };

  try {
    await supabaseAdmin
      .from('profiles')
      .update({
        is_online,
        last_seen: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', req.user!.id);

    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to update status' });
  }
});
