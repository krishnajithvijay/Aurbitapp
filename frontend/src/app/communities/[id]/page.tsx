'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Community, Post } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { PostCard } from '@/components/feed/PostCard';
import { CreatePost } from '@/components/feed/CreatePost';
import { useAuth } from '@/context/AuthContext';

export default function CommunityDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [community, setCommunity] = useState<Community | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [isMember, setIsMember] = useState(false);
  const { supabaseUser } = useAuth();
  const supabase = createClient();
  const router = useRouter();

  useEffect(() => {
    const load = async () => {
      const [{ data: comm }, { data: ps }] = await Promise.all([
        supabase.from('communities').select('*').eq('id', id).single(),
        supabase.from('posts').select('*, author:profiles!user_id(*)').eq('community_id', id).order('created_at', { ascending: false }),
      ]);
      setCommunity(comm);
      setPosts(ps ?? []);

      if (supabaseUser && comm) {
        const { data: member } = await supabase
          .from('community_members')
          .select('id')
          .match({ community_id: id, user_id: supabaseUser.id })
          .single();
        setIsMember(!!member);
      }
      setLoading(false);
    };
    load();
  }, [id, supabaseUser]);

  const joinLeave = async () => {
    if (!supabaseUser || !community) return;
    if (isMember) {
      await supabase.from('community_members').delete().match({ community_id: id, user_id: supabaseUser.id });
      setIsMember(false);
    } else {
      await supabase.from('community_members').insert({
        community_id: id,
        user_id: supabaseUser.id,
        role: 'member',
        joined_at: new Date().toISOString(),
      });
      setIsMember(true);
    }
  };

  const refreshPosts = async () => {
    const { data } = await supabase
      .from('posts')
      .select('*, author:profiles!user_id(*)')
      .eq('community_id', id)
      .order('created_at', { ascending: false });
    setPosts(data ?? []);
  };

  if (loading) return (
    <AppShell>
      <div className="flex justify-center py-12">
        <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
      </div>
    </AppShell>
  );

  return (
    <AppShell>
      <div>
        <button onClick={() => router.back()} className="text-zinc-400 hover:text-white text-sm mb-4 flex items-center gap-2">
          ← Back
        </button>
        {community && (
          <div className="bg-[#111] border border-[#222] rounded-2xl p-5 mb-4">
            <div className="flex items-start gap-4">
              <div className="w-16 h-16 rounded-2xl bg-violet-600 flex items-center justify-center text-2xl flex-shrink-0">
                🏘️
              </div>
              <div className="flex-1">
                <h1 className="text-xl font-bold text-white">{community.name}</h1>
                {community.description && (
                  <p className="text-zinc-400 text-sm mt-1">{community.description}</p>
                )}
                <p className="text-xs text-zinc-600 mt-2">{community.member_count} members</p>
              </div>
              <button
                onClick={joinLeave}
                className={`text-sm font-medium px-4 py-2 rounded-xl transition-colors ${
                  isMember
                    ? 'bg-[#222] text-zinc-400'
                    : 'bg-violet-600 hover:bg-violet-700 text-white'
                }`}
              >
                {isMember ? 'Leave' : 'Join'}
              </button>
            </div>
          </div>
        )}

        {isMember && <CreatePost onPost={refreshPosts} communityId={id} />}

        {posts.map(post => <PostCard key={post.id} post={post} />)}
      </div>
    </AppShell>
  );
}
