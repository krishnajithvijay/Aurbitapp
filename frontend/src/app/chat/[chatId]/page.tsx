'use client';
import { useEffect, useState, useRef, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Message, Chat, User } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { useAuth } from '@/context/AuthContext';
import { encryptMessage, decryptMessage } from '@/lib/encryption';
import { formatDistanceToNow } from 'date-fns';

const supabase = createClient();

export default function ChatRoomPage() {
  const { chatId } = useParams<{ chatId: string }>();
  const [chat, setChat] = useState<Chat | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [decryptedMessages, setDecryptedMessages] = useState<Map<string, string>>(new Map());
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [otherUser, setOtherUser] = useState<User | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const { supabaseUser } = useAuth();
  const router = useRouter();

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const decryptAll = useCallback(async (msgs: Message[], theirPublicKey?: string) => {
    if (!theirPublicKey) return;
    const map = new Map<string, string>();
    for (const msg of msgs) {
      if (msg.encrypted_content && msg.nonce && msg.sender_id !== supabaseUser?.id) {
        const decrypted = await decryptMessage(msg.encrypted_content, msg.nonce, theirPublicKey);
        if (decrypted) map.set(msg.id, decrypted);
      }
    }
    setDecryptedMessages(map);
  }, [supabaseUser?.id]);

  useEffect(() => {
    if (!supabaseUser) return;
    const load = async () => {
      const { data: chatData } = await supabase.from('chats').select('*').eq('id', chatId).single();
      setChat(chatData);

      if (chatData) {
        const otherId = chatData.participant1_id === supabaseUser.id
          ? chatData.participant2_id
          : chatData.participant1_id;
        const { data: user } = await supabase.from('profiles').select('*').eq('id', otherId).single();
        setOtherUser(user);

        const { data: msgs } = await supabase
          .from('messages')
          .select('*')
          .eq('chat_id', chatId)
          .order('created_at', { ascending: true })
          .limit(50);

        const msgList = msgs ?? [];
        setMessages(msgList);
        await decryptAll(msgList, user?.public_key);
      }
      setLoading(false);
    };
    load();

    const channel = supabase
      .channel(`chat-${chatId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `chat_id=eq.${chatId}` },
        (payload) => {
          setMessages(prev => [...prev, payload.new as Message]);
          scrollToBottom();
        })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chatId, supabaseUser]);

  useEffect(() => { scrollToBottom(); }, [messages]);

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !supabaseUser || !chat) return;

    const content = newMessage.trim();
    setNewMessage('');

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const msgData: Record<string, any> = {
      chat_id: chatId,
      sender_id: supabaseUser.id,
      type: 'text',
      status: 'sent',
      created_at: new Date().toISOString(),
      is_deleted: false,
    };

    if (otherUser?.public_key) {
      const encrypted = await encryptMessage(content, otherUser.public_key);
      if (encrypted) {
        msgData.encrypted_content = encrypted.encryptedContent;
        msgData.nonce = encrypted.nonce;
      } else {
        msgData.content = content;
      }
    } else {
      msgData.content = content;
    }

    await supabase.from('messages').insert(msgData);
    await supabase.from('chats').update({ updated_at: new Date().toISOString() }).eq('id', chatId);
  };

  const getMessageText = (msg: Message): string => {
    if (msg.sender_id === supabaseUser?.id) {
      return msg.content ?? '[encrypted]';
    }
    return decryptedMessages.get(msg.id) ?? (msg.content ?? '[encrypted message]');
  };

  return (
    <AppShell>
      <div className="flex flex-col h-[calc(100vh-8rem)]">
        {/* Header */}
        <div className="flex items-center gap-3 py-3 border-b border-[#222] mb-4">
          <button onClick={() => router.back()} className="text-zinc-400 hover:text-white mr-1">←</button>
          <div className="w-9 h-9 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold overflow-hidden">
            {otherUser?.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={otherUser.avatar_url} alt="" className="w-full h-full object-cover" />
            ) : (
              (otherUser?.display_name || otherUser?.username || '?')[0].toUpperCase()
            )}
          </div>
          <div>
            <p className="text-sm font-semibold text-white">{otherUser?.display_name || otherUser?.username}</p>
            <p className="text-xs text-zinc-500 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-green-400 inline-block" />
              E2E Encrypted
            </p>
          </div>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto space-y-3 scrollbar-hide">
          {loading ? (
            <div className="flex justify-center py-8">
              <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : messages.map(msg => {
            const isMine = msg.sender_id === supabaseUser?.id;
            const text = getMessageText(msg);
            return (
              <div key={msg.id} className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}>
                <div className={`max-w-[75%] px-4 py-2.5 rounded-2xl text-sm ${
                  isMine
                    ? 'bg-violet-600 text-white rounded-br-sm'
                    : 'bg-[#1a1a1a] text-white rounded-bl-sm border border-[#2a2a2a]'
                }`}>
                  <p className="whitespace-pre-wrap break-words">{text}</p>
                  <p className={`text-xs mt-1 ${isMine ? 'text-violet-200' : 'text-zinc-600'}`}>
                    {formatDistanceToNow(new Date(msg.created_at), { addSuffix: true })}
                  </p>
                </div>
              </div>
            );
          })}
          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <form onSubmit={sendMessage} className="flex gap-3 pt-4 border-t border-[#222]">
          <input
            value={newMessage}
            onChange={e => setNewMessage(e.target.value)}
            placeholder="Type a message..."
            className="flex-1 bg-[#111] border border-[#333] rounded-xl px-4 py-3 text-white placeholder-zinc-600 text-sm focus:outline-none focus:border-violet-500 transition-colors"
          />
          <button
            type="submit"
            disabled={!newMessage.trim()}
            className="bg-violet-600 hover:bg-violet-700 disabled:opacity-40 text-white px-4 py-3 rounded-xl transition-colors"
          >
            ↗
          </button>
        </form>
      </div>
    </AppShell>
  );
}
