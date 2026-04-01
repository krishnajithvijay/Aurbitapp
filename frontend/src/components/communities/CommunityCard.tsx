'use client';
import Link from 'next/link';
import { Community } from '@/types';

interface CommunityCardProps {
  community: Community;
  onJoin?: (id: string) => void;
}

export function CommunityCard({ community, onJoin }: CommunityCardProps) {
  return (
    <div className="bg-[#111] border border-[#222] rounded-2xl p-4">
      <div className="flex items-start gap-3">
        <div className="w-12 h-12 rounded-xl bg-violet-600 flex items-center justify-center text-xl flex-shrink-0">
          {community.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={community.avatar_url} alt="" className="w-full h-full object-cover rounded-xl" />
          ) : '🏘️'}
        </div>
        <div className="flex-1 min-w-0">
          <Link href={`/communities/${community.id}`}>
            <h3 className="font-semibold text-white hover:text-violet-400 transition-colors">{community.name}</h3>
          </Link>
          {community.description && (
            <p className="text-sm text-zinc-400 mt-0.5 line-clamp-2">{community.description}</p>
          )}
          <p className="text-xs text-zinc-600 mt-1">
            {community.member_count} members · {community.post_count} posts
          </p>
        </div>
        {onJoin && (
          <button
            onClick={() => !community.is_joined && onJoin(community.id)}
            className={`text-sm font-medium px-4 py-1.5 rounded-xl transition-colors flex-shrink-0 ${
              community.is_joined
                ? 'bg-[#222] text-zinc-500 cursor-default'
                : 'bg-violet-600/20 text-violet-400 border border-violet-600/30 hover:bg-violet-600/30'
            }`}
          >
            {community.is_joined ? 'Joined' : 'Join'}
          </button>
        )}
      </div>
    </div>
  );
}
