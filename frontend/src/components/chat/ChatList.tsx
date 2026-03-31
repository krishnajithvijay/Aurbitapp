'use client';
import Link from 'next/link';
import { Chat } from '@/types';
import { formatDistanceToNow } from 'date-fns';

interface ChatListProps {
  chats: Chat[];
}

export function ChatList({ chats }: ChatListProps) {
  if (chats.length === 0) {
    return (
      <div className="text-center py-16">
        <span className="text-4xl mb-4 block">💬</span>
        <p className="text-zinc-400">No conversations yet</p>
        <p className="text-zinc-600 text-sm mt-1">Go to Orbit to start a chat</p>
      </div>
    );
  }

  return (
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
                <p className="text-sm font-medium text-white">{chat.other_user?.display_name || chat.other_user?.username}</p>
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
  );
}
