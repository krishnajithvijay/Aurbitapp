'use client';
import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Post } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { PostCard } from '@/components/feed/PostCard';
import { CreatePost } from '@/components/feed/CreatePost';
import { useAuth } from '@/context/AuthContext';

export default function FeedPage() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const { supabaseUser } = useAuth();
  const supabase = createClient();

  const fetchPosts = useCallback(async () => {
    const { data } = await supabase
      .from('posts')
      .select('*, author:profiles!user_id(*)')
      .order('created_at', { ascending: false })
      .limit(20);

    if (data && supabaseUser) {
      const { data: likes } = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', supabaseUser.id)
        .in('post_id', data.map((p: Post) => p.id));

      const likedIds = new Set((likes ?? []).map((l: { post_id: string }) => l.post_id));
      setPosts(data.map((p: Post) => ({ ...p, is_liked: likedIds.has(p.id) })));
    } else {
      setPosts(data ?? []);
    }
    setLoading(false);
  }, [supabaseUser]);

  useEffect(() => {
    fetchPosts();

    const channel = supabase
      .channel('posts-feed')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, () => {
        fetchPosts();
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [fetchPosts]);

  return (
    <AppShell>
      <div>
        <div className="flex items-center justify-between mb-4 pt-2">
          <h1 className="text-xl font-bold text-white">Feed</h1>
        </div>

        <CreatePost onPost={fetchPosts} />

        {loading ? (
          <div className="space-y-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="bg-[#111] border border-[#222] rounded-2xl p-4 animate-pulse">
                <div className="flex gap-3 mb-3">
                  <div className="w-10 h-10 bg-[#222] rounded-full" />
                  <div className="flex-1 space-y-2">
                    <div className="h-3 bg-[#222] rounded w-1/3" />
                    <div className="h-3 bg-[#222] rounded w-1/4" />
                  </div>
                </div>
                <div className="space-y-2">
                  <div className="h-3 bg-[#222] rounded" />
                  <div className="h-3 bg-[#222] rounded w-3/4" />
                </div>
              </div>
            ))}
          </div>
        ) : posts.length === 0 ? (
          <div className="text-center py-16">
            <span className="text-4xl mb-4 block">🪐</span>
            <p className="text-zinc-400">No posts yet. Be the first!</p>
          </div>
        ) : (
          posts.map(post => (
            <PostCard
              key={post.id}
              post={post}
              onUpdate={(updated) => {
                setPosts(prev => prev.map(p => p.id === updated.id ? updated : p));
              }}
            />
          ))
        )}
      </div>
    </AppShell>
  );
}
