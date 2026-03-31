'use client';
import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Post } from '@/types';
import { useAuth } from '@/context/AuthContext';

export function useFeed() {
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
      .channel('posts-feed-hook')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, () => {
        fetchPosts();
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [fetchPosts]);

  return { posts, loading, refresh: fetchPosts, setPosts };
}
