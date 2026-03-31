'use client';
import { User } from '@/types';

interface OrbitListProps {
  users: User[];
  onChat?: (userId: string) => void;
}

export function OrbitList({ users, onChat }: OrbitListProps) {
  if (users.length === 0) {
    return (
      <p className="text-zinc-600 text-sm text-center py-4">
        No one in your orbit yet. Search above!
      </p>
    );
  }

  return (
    <div className="space-y-2">
      {users.map(user => (
        <div key={user.id} className="flex items-center gap-3 p-2 rounded-xl hover:bg-[#1a1a1a] transition-colors">
          <div className="relative">
            <div className="w-10 h-10 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold overflow-hidden">
              {user.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={user.avatar_url} alt="" className="w-full h-full object-cover" />
              ) : (
                (user.display_name || user.username)[0].toUpperCase()
              )}
            </div>
            {user.is_online && (
              <span className="absolute bottom-0 right-0 w-2.5 h-2.5 bg-green-400 rounded-full border-2 border-black" />
            )}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-white">{user.display_name || user.username}</p>
            <p className="text-xs text-zinc-500">@{user.username}</p>
          </div>
          {onChat && (
            <button
              onClick={() => onChat(user.id)}
              className="text-xs bg-[#222] hover:bg-[#2a2a2a] text-zinc-300 px-3 py-1.5 rounded-lg transition-colors"
            >
              💬 Chat
            </button>
          )}
        </div>
      ))}
    </div>
  );
}
