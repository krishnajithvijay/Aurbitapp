'use client';
import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/context/AuthContext';

interface CreatePostProps {
  onPost?: () => void;
  communityId?: string;
}

const supabase = createClient();

export function CreatePost({ onPost, communityId }: CreatePostProps) {
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(false);
  const { supabaseUser, profile } = useAuth();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim() || !supabaseUser) return;
    setLoading(true);

    await supabase.from('posts').insert({
      user_id: supabaseUser.id,
      content: content.trim(),
      community_id: communityId ?? null,
      created_at: new Date().toISOString(),
    });

    setContent('');
    setLoading(false);
    onPost?.();
  };

  return (
    <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-4">
      <div className="flex gap-3">
        <div className="w-10 h-10 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold overflow-hidden flex-shrink-0">
          {profile?.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={profile.avatar_url} alt="" className="w-full h-full object-cover" />
          ) : (
            (profile?.display_name || profile?.username || 'A')[0].toUpperCase()
          )}
        </div>
        <form onSubmit={submit} className="flex-1">
          <textarea
            value={content}
            onChange={e => setContent(e.target.value)}
            placeholder="What's happening in your orbit?"
            maxLength={2000}
            rows={3}
            className="w-full bg-transparent text-white placeholder-zinc-600 text-sm resize-none focus:outline-none"
          />
          <div className="flex justify-between items-center mt-3 pt-3 border-t border-[#222]">
            <span className="text-xs text-zinc-600">{content.length}/2000</span>
            <button
              type="submit"
              disabled={!content.trim() || loading}
              className="bg-violet-600 hover:bg-violet-700 disabled:opacity-40 text-white text-sm font-semibold px-5 py-2 rounded-xl transition-colors"
            >
              {loading ? '...' : 'Post'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
