import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase';
import { requireAuth, AuthRequest } from '../middleware/auth';

export const chatRouter = Router();

// Get user's chats
chatRouter.get('/', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('chats')
      .select('*')
      .or(`participant1_id.eq.${req.user!.id},participant2_id.eq.${req.user!.id}`)
      .order('updated_at', { ascending: false, nullsFirst: false });

    if (error) throw error;
    res.json(data ?? []);
  } catch {
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
});

// Get or create chat with user
chatRouter.post('/with/:userId', requireAuth, async (req: AuthRequest, res) => {
  const { userId } = req.params;
  const myId = req.user!.id;

  try {
    // Check if chat exists
    const { data: existing } = await supabaseAdmin
      .from('chats')
      .select('*')
      .or(`and(participant1_id.eq.${myId},participant2_id.eq.${userId}),and(participant1_id.eq.${userId},participant2_id.eq.${myId})`)
      .single();

    if (existing) {
      res.json(existing);
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('chats')
      .insert({
        participant1_id: myId,
        participant2_id: userId,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch {
    res.status(500).json({ error: 'Failed to create chat' });
  }
});

// Get messages in chat (paginated)
chatRouter.get('/:chatId/messages', requireAuth, async (req: AuthRequest, res) => {
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 50;
  const from = (page - 1) * limit;

  try {
    // Verify user is participant
    const { data: chat } = await supabaseAdmin
      .from('chats')
      .select('participant1_id, participant2_id')
      .eq('id', req.params.chatId)
      .single();

    if (!chat || (chat.participant1_id !== req.user!.id && chat.participant2_id !== req.user!.id)) {
      res.status(403).json({ error: 'Access denied' });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('messages')
      .select('*')
      .eq('chat_id', req.params.chatId)
      .order('created_at', { ascending: false })
      .range(from, from + limit - 1);

    if (error) throw error;
    res.json((data ?? []).reverse());
  } catch {
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// Send message
chatRouter.post('/:chatId/messages', requireAuth, async (req: AuthRequest, res) => {
  const { content, encrypted_content, nonce, mac, type, media_url, reply_to_id } = req.body as {
    content?: string;
    encrypted_content?: string;
    nonce?: string;
    mac?: string;
    type?: string;
    media_url?: string;
    reply_to_id?: string;
  };

  if (!content && !encrypted_content) {
    res.status(400).json({ error: 'Message content is required' });
    return;
  }

  try {
    // Verify user is participant
    const { data: chat } = await supabaseAdmin
      .from('chats')
      .select('participant1_id, participant2_id')
      .eq('id', req.params.chatId)
      .single();

    if (!chat || (chat.participant1_id !== req.user!.id && chat.participant2_id !== req.user!.id)) {
      res.status(403).json({ error: 'Access denied' });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('messages')
      .insert({
        chat_id: req.params.chatId,
        sender_id: req.user!.id,
        content: content ?? null,
        encrypted_content: encrypted_content ?? null,
        nonce: nonce ?? null,
        mac: mac ?? null,
        type: type ?? 'text',
        status: 'sent',
        media_url: media_url ?? null,
        reply_to_id: reply_to_id ?? null,
        created_at: new Date().toISOString(),
        is_deleted: false,
      })
      .select()
      .single();

    if (error) throw error;

    // Update chat updated_at
    await supabaseAdmin
      .from('chats')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', req.params.chatId);

    res.status(201).json(data);
  } catch {
    res.status(500).json({ error: 'Failed to send message' });
  }
});
