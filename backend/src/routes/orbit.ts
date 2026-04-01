import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const orbitRouter = Router();

// Get user's orbit (friends)
orbitRouter.get('/', requireAuth, async (req: AuthRequest, res) => {
  const userId = req.user!.id;

  try {
    const { data, error } = await supabaseAdmin
      .from('orbits')
      .select('*')
      .or(`requester_id.eq.${userId},addressee_id.eq.${userId}`)
      .eq('status', 'accepted');

    if (error) throw error;

    // Fetch user details for each orbit relationship
    const orbits = await Promise.all((data ?? []).map(async (orbit: { id: string; requester_id: string; addressee_id: string; status: string; created_at: string }) => {
      const otherId = orbit.requester_id === userId ? orbit.addressee_id : orbit.requester_id;
      const { data: user } = await supabaseAdmin.from('profiles').select('*').eq('id', otherId).single();
      return { ...orbit, user };
    }));

    res.json(orbits);
  } catch {
    res.status(500).json({ error: 'Failed to fetch orbit' });
  }
});

// Get pending requests
orbitRouter.get('/pending', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('orbits')
      .select('*')
      .eq('addressee_id', req.user!.id)
      .eq('status', 'pending');

    if (error) throw error;

    const requests = await Promise.all((data ?? []).map(async (orbit: { id: string; requester_id: string; addressee_id: string; status: string; created_at: string }) => {
      const { data: user } = await supabaseAdmin.from('profiles').select('*').eq('id', orbit.requester_id).single();
      return { ...orbit, user };
    }));

    res.json(requests);
  } catch {
    res.status(500).json({ error: 'Failed to fetch pending requests' });
  }
});

// Send orbit request
orbitRouter.post('/request/:userId', requireAuth, async (req: AuthRequest, res) => {
  const requesterId = req.user!.id;
  const addresseeId = req.params.userId;

  if (requesterId === addresseeId) {
    res.status(400).json({ error: 'Cannot send request to yourself' });
    return;
  }

  try {
    const { data: existing } = await supabaseAdmin
      .from('orbits')
      .select('id, status')
      .or(`and(requester_id.eq.${requesterId},addressee_id.eq.${addresseeId}),and(requester_id.eq.${addresseeId},addressee_id.eq.${requesterId})`)
      .single();

    if (existing) {
      res.status(409).json({ error: 'Orbit relationship already exists', status: existing.status });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('orbits')
      .insert({
        requester_id: requesterId,
        addressee_id: addresseeId,
        status: 'pending',
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;

    // Send notification
    await supabaseAdmin.from('notifications').insert({
      user_id: addresseeId,
      type: 'orbit_request',
      actor_id: requesterId,
      title: 'Orbit request',
      body: 'Someone wants to orbit with you',
      reference_id: data.id,
      is_read: false,
      created_at: new Date().toISOString(),
    });

    res.status(201).json(data);
  } catch {
    res.status(500).json({ error: 'Failed to send orbit request' });
  }
});

// Accept orbit request
orbitRouter.post('/accept/:orbitId', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('orbits')
      .update({ status: 'accepted' })
      .eq('id', req.params.orbitId)
      .eq('addressee_id', req.user!.id) // Only addressee can accept
      .select()
      .single();

    if (error || !data) {
      res.status(404).json({ error: 'Orbit request not found' });
      return;
    }

    // Send notification to requester
    await supabaseAdmin.from('notifications').insert({
      user_id: data.requester_id,
      type: 'orbit_accepted',
      actor_id: req.user!.id,
      title: 'Orbit accepted',
      body: 'Your orbit request was accepted!',
      reference_id: data.id,
      is_read: false,
      created_at: new Date().toISOString(),
    });

    res.json(data);
  } catch {
    res.status(500).json({ error: 'Failed to accept orbit request' });
  }
});

// Remove from orbit
orbitRouter.delete('/:orbitId', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { error } = await supabaseAdmin
      .from('orbits')
      .delete()
      .eq('id', req.params.orbitId)
      .or(`requester_id.eq.${req.user!.id},addressee_id.eq.${req.user!.id}`);

    if (error) throw error;
    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to remove from orbit' });
  }
});
