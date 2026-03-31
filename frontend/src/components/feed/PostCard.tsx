'use client';
import { useState } from 'react';
import Link from 'next/link';
import { Post } from '@/types';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/context/AuthContext';
import { formatDistanceToNow } from 'date-fns';

interface PostCardProps {
  post: Post;
  onUpdate?: (post: Post) => void;
}

export function PostCard({ post, onUpdate }: PostCardProps) {
  const { supabaseUser } = useAuth();
  const [isLiked, setIsLiked] = useState(post.is_liked ?? false);
  const [likesCount, setLikesCount] = useState(post.likes_count);
  const supabase = createClient();

  const toggleLike = async () => {
    if (!supabaseUser) return;
    const newLiked = !isLiked;
    setIsLiked(newLiked);
    setLikesCount(c => newLiked ? c + 1 : c - 1);

    if (newLiked) {
      await supabase.from('post_likes').insert({ post_id: post.id, user_id: supabaseUser.id });
    } else {
      await supabase.from('post_likes').delete()
        .match({ post_id: post.id, user_id: supabaseUser.id });
    }
    onUpdate?.({ ...post, is_liked: newLiked, likes_count: newLiked ? post.likes_count + 1 : post.likes_count - 1 });
  };

  const timeAgo = (() => {
    try {
      return formatDistanceToNow(new Date(post.created_at), { addSuffix: true });
    } catch {
      return '';
    }
  })();

  return (
    <article className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-3">
      {/* Author row */}
      <div className="flex items-center gap-3 mb-3">
        <Link href={`/profile/${post.author?.username}`}>
          <div className="w-10 h-10 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold overflow-hidden flex-shrink-0">
            {post.author?.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={post.author.avatar_url} alt="" className="w-full h-full object-cover" />
            ) : (
              (post.author?.display_name || post.author?.username || 'A')[0].toUpperCase()
            )}
          </div>
        </Link>
        <div className="flex-1 min-w-0">
          <Link href={`/profile/${post.author?.username}`} className="text-sm font-semibold text-white hover:text-violet-400 transition-colors">
            {post.author?.display_name || post.author?.username || 'Unknown'}
          </Link>
          <p className="text-xs text-zinc-500">@{post.author?.username} · {timeAgo}</p>
        </div>
      </div>

      {/* Content */}
      <p className="text-white text-sm leading-relaxed mb-3 whitespace-pre-wrap">{post.content}</p>

      {/* Media */}
      {post.media_url && post.media_type?.startsWith('image') && (
        <div className="rounded-xl overflow-hidden mb-3">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={post.media_url} alt="" className="w-full max-h-80 object-cover" />
        </div>
      )}

      {/* Actions */}
      <div className="flex items-center gap-6 mt-2">
        <button
          onClick={toggleLike}
          className={`flex items-center gap-2 text-sm transition-colors ${isLiked ? 'text-red-400' : 'text-zinc-500 hover:text-red-400'}`}
        >
          <span>{isLiked ? '❤️' : '🤍'}</span>
          <span>{likesCount}</span>
        </button>

        <Link
          href={`/feed/${post.id}`}
          className="flex items-center gap-2 text-sm text-zinc-500 hover:text-violet-400 transition-colors"
        >
          <span>💬</span>
          <span>{post.comments_count}</span>
        </Link>

        <button className="flex items-center gap-2 text-sm text-zinc-500 hover:text-blue-400 transition-colors ml-auto">
          <span>↗️</span>
        </button>
      </div>
    </article>
  );
}
