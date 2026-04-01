'use client';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Chat } from '@/types';
import { useAuth } from '@/context/AuthContext';

const supabase = createClient();

export function useChat() {
  const [chats, setChats] = useState<Chat[]>([]);
  const [loading, setLoading] = useState(true);
  const { supabaseUser } = useAuth();

  useEffect(() => {
    if (!supabaseUser) return;

    const load = async () => {
      const { data } = await supabase
        .from('chats')
        .select('*')
        .or(`participant1_id.eq.${supabaseUser.id},participant2_id.eq.${supabaseUser.id}`)
        .order('updated_at', { ascending: false });

      if (!data) { setLoading(false); return; }

      const enriched = await Promise.all(data.map(async (chat: Chat) => {
        const otherId = chat.participant1_id === supabaseUser.id
          ? chat.participant2_id
          : chat.participant1_id;
        const { data: user } = await supabase.from('profiles').select('*').eq('id', otherId).single();
        return { ...chat, other_user: user };
      }));
      setChats(enriched);
      setLoading(false);
    };
    load();
  }, [supabaseUser]);

  return { chats, loading };
}
