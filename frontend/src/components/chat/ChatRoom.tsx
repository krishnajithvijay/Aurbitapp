'use client';
import { useEffect, useState, useRef, useCallback } from 'react';
import { Message, User } from '@/types';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/context/AuthContext';
import { encryptMessage, decryptMessage } from '@/lib/encryption';
import { MessageBubble } from './MessageBubble';

interface ChatRoomProps {
  chatId: string;
  otherUser: User | null;
}

const supabase = createClient();

export function ChatRoom({ chatId, otherUser }: ChatRoomProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [decryptedMessages, setDecryptedMessages] = useState<Map<string, string>>(new Map());
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const { supabaseUser } = useAuth();

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
      const { data: msgs } = await supabase
        .from('messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', { ascending: true })
        .limit(50);

      const msgList = msgs ?? [];
      setMessages(msgList);
      await decryptAll(msgList, otherUser?.public_key);
      setLoading(false);
    };
    load();

    const channel = supabase
      .channel(`chat-room-${chatId}`)
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
    if (!newMessage.trim() || !supabaseUser) return;

    const content = newMessage.trim();
    setNewMessage('');

    const msgData: Record<string, unknown> = {
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
    <div className="flex flex-col h-[calc(100vh-8rem)]">
      {/* Messages */}
      <div className="flex-1 overflow-y-auto space-y-3 scrollbar-hide">
        {loading ? (
          <div className="flex justify-center py-8">
            <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : messages.map(msg => (
          <MessageBubble
            key={msg.id}
            message={msg}
            isMine={msg.sender_id === supabaseUser?.id}
            text={getMessageText(msg)}
          />
        ))}
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
  );
}
