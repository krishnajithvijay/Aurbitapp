'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { Chat } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { useAuth } from '@/context/AuthContext';
import { formatDistanceToNow } from 'date-fns';

const supabase = createClient();

export default function ChatListPage() {
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

  return (
    <AppShell>
      <div>
        <div className="flex items-center justify-between mb-4 pt-2">
          <h1 className="text-xl font-bold text-white">Messages</h1>
        </div>

        {loading ? (
          <div className="flex justify-center py-12">
            <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : chats.length === 0 ? (
          <div className="text-center py-16">
            <span className="text-4xl mb-4 block">💬</span>
            <p className="text-zinc-400">No conversations yet</p>
            <p className="text-zinc-600 text-sm mt-1">Go to Orbit to start a chat</p>
          </div>
        ) : (
          <div className="space-y-2">
            {chats.map(chat => (
              <Link key={chat.id} href={`/chat/${chat.id}`}>
                <div className="flex items-center gap-3 bg-[#111] hover:bg-[#181818] border border-[#222] rounded-xl p-3 transition-colors">
                  <div className="w-12 h-12 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold overflow-hidden flex-shrink-0">
                    {chat.other_user?.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={chat.other_user.avatar_url} alt="" className="w-full h-full object-cover" />
                    ) : (
                      (chat.other_user?.display_name || chat.other_user?.username || '?')[0].toUpperCase()
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex justify-between items-center">
                      <p className="text-sm font-medium text-white">
                        {chat.other_user?.display_name || chat.other_user?.username}
                      </p>
                      {chat.updated_at && (
                        <span className="text-xs text-zinc-600">
                          {formatDistanceToNow(new Date(chat.updated_at), { addSuffix: true })}
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-zinc-500 truncate">@{chat.other_user?.username}</p>
                    {chat.unread_count > 0 && (
                      <span className="inline-block bg-violet-600 text-white text-xs rounded-full px-2 py-0.5 mt-1">
                        {chat.unread_count}
                      </span>
                    )}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </AppShell>
  );
}
