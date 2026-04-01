'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { User, Post } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { PostCard } from '@/components/feed/PostCard';
import { useAuth } from '@/context/AuthContext';
import { formatDistanceToNow } from 'date-fns';

const supabase = createClient();

export default function UserProfilePage() {
  const { username } = useParams<{ username: string }>();
  const [user, setUser] = useState<User | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [orbitStatus, setOrbitStatus] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const { supabaseUser } = useAuth();
  const router = useRouter();

  useEffect(() => {
    const load = async () => {
      const { data: userData } = await supabase
        .from('profiles')
        .select('*')
        .eq('username', username)
        .single();
      setUser(userData);

      if (userData) {
        const { data: ps } = await supabase
          .from('posts')
          .select('*, author:profiles!user_id(*)')
          .eq('user_id', userData.id)
          .order('created_at', { ascending: false });
        setPosts(ps ?? []);

        if (supabaseUser) {
          const { data: orbit } = await supabase
            .from('orbits')
            .select('status')
            .or(
              `and(requester_id.eq.${supabaseUser.id},addressee_id.eq.${userData.id}),` +
              `and(requester_id.eq.${userData.id},addressee_id.eq.${supabaseUser.id})`
            )
            .single();
          setOrbitStatus(orbit?.status ?? null);
        }
      }
      setLoading(false);
    };
    load();
  }, [username, supabaseUser]);

  const sendOrbitRequest = async () => {
    if (!supabaseUser || !user) return;
    await supabase.from('orbits').insert({
      requester_id: supabaseUser.id,
      addressee_id: user.id,
      status: 'pending',
      created_at: new Date().toISOString(),
    });
    setOrbitStatus('pending');
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
        <button onClick={() => router.back()} className="text-zinc-400 hover:text-white text-sm mb-4">
          ← Back
        </button>
        {user && (
          <>
            <div className="bg-[#111] border border-[#222] rounded-2xl p-5 mb-4">
              <div className="flex items-start gap-4">
                <div className="w-16 h-16 rounded-full bg-violet-600 flex items-center justify-center text-2xl font-bold overflow-hidden">
                  {user.avatar_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={user.avatar_url} alt="" className="w-full h-full object-cover" />
                  ) : (
                    (user.display_name || user.username)[0].toUpperCase()
                  )}
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h2 className="text-xl font-bold text-white">{user.display_name || user.username}</h2>
                    {user.is_verified && <span className="text-blue-400 text-sm">✓</span>}
                  </div>
                  <p className="text-zinc-500 text-sm">@{user.username}</p>
                  {user.bio && <p className="text-zinc-300 text-sm mt-2">{user.bio}</p>}
                  <div className="flex items-center gap-2 mt-2">
                    <span className={`w-2 h-2 rounded-full ${user.is_online ? 'bg-green-400' : 'bg-zinc-600'}`} />
                    <span className="text-xs text-zinc-500">
                      {user.is_online
                        ? 'Online'
                        : user.last_seen
                        ? `Last seen ${formatDistanceToNow(new Date(user.last_seen), { addSuffix: true })}`
                        : 'Offline'}
                    </span>
                  </div>
                </div>
                {supabaseUser && supabaseUser.id !== user.id && (
                  <button
                    onClick={sendOrbitRequest}
                    disabled={orbitStatus !== null}
                    className={`text-sm font-medium px-4 py-2 rounded-xl transition-colors ${
                      orbitStatus === 'accepted'
                        ? 'bg-[#222] text-zinc-500 cursor-default'
                        : orbitStatus === 'pending'
                        ? 'bg-amber-600/20 text-amber-400 border border-amber-600/30'
                        : 'bg-violet-600 hover:bg-violet-700 text-white'
                    }`}
                  >
                    {orbitStatus === 'accepted'
                      ? '✓ In Orbit'
                      : orbitStatus === 'pending'
                      ? 'Pending'
                      : '+ Orbit'}
                  </button>
                )}
              </div>
            </div>

            <h3 className="text-sm font-semibold text-zinc-400 mb-3">Posts</h3>
            {posts.map(post => <PostCard key={post.id} post={post} />)}
          </>
        )}
      </div>
    </AppShell>
  );
}
