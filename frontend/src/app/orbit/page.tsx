'use client';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Orbit, User } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { useAuth } from '@/context/AuthContext';
import { useRouter } from 'next/navigation';

const supabase = createClient();

export default function OrbitPage() {
  const [orbitUsers, setOrbitUsers] = useState<User[]>([]);
  const [pendingRequests, setPendingRequests] = useState<Orbit[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const { supabaseUser } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!supabaseUser) return;
    loadOrbit();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [supabaseUser]);

  const loadOrbit = async () => {
    if (!supabaseUser) return;
    const [{ data: sent }, { data: received }] = await Promise.all([
      supabase.from('orbits').select('*').eq('requester_id', supabaseUser.id).eq('status', 'accepted'),
      supabase.from('orbits').select('*').eq('addressee_id', supabaseUser.id).eq('status', 'pending'),
    ]);

    const friendIds = (sent ?? []).map((o: Orbit) => o.addressee_id);
    if (friendIds.length > 0) {
      const { data: users } = await supabase.from('profiles').select('*').in('id', friendIds);
      setOrbitUsers(users ?? []);
    } else {
      setOrbitUsers([]);
    }

    const pendingWithUsers = await Promise.all((received ?? []).map(async (orbit: Orbit) => {
      const { data: user } = await supabase.from('profiles').select('*').eq('id', orbit.requester_id).single();
      return { ...orbit, user };
    }));
    setPendingRequests(pendingWithUsers);
    setLoading(false);
  };

  const searchUsers = async () => {
    if (!searchQuery.trim()) { setSearchResults([]); return; }
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .or(`username.ilike.%${searchQuery}%,display_name.ilike.%${searchQuery}%`)
      .neq('id', supabaseUser?.id ?? '')
      .limit(10);
    setSearchResults(data ?? []);
  };

  const sendOrbitRequest = async (userId: string) => {
    if (!supabaseUser) return;
    await supabase.from('orbits').insert({
      requester_id: supabaseUser.id,
      addressee_id: userId,
      status: 'pending',
      created_at: new Date().toISOString(),
    });
    setSearchResults(prev => prev.filter(u => u.id !== userId));
  };

  const acceptRequest = async (orbitId: string) => {
    await supabase.from('orbits').update({ status: 'accepted' }).eq('id', orbitId);
    loadOrbit();
  };

  const startChat = async (userId: string) => {
    if (!supabaseUser) return;
    const { data: existing } = await supabase
      .from('chats')
      .select('id')
      .or(`and(participant1_id.eq.${supabaseUser.id},participant2_id.eq.${userId}),and(participant1_id.eq.${userId},participant2_id.eq.${supabaseUser.id})`)
      .single();

    if (existing) {
      router.push(`/chat/${existing.id}`);
    } else {
      const { data: newChat } = await supabase.from('chats').insert({
        participant1_id: supabaseUser.id,
        participant2_id: userId,
        created_at: new Date().toISOString(),
      }).select().single();
      if (newChat) router.push(`/chat/${newChat.id}`);
    }
  };

  return (
    <AppShell>
      <div>
        <div className="flex items-center justify-between mb-4 pt-2">
          <h1 className="text-xl font-bold text-white">🪐 Orbit</h1>
        </div>

        {/* Search */}
        <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-4">
          <div className="flex gap-3">
            <input
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && searchUsers()}
              placeholder="Search users..."
              className="flex-1 bg-[#0a0a0a] border border-[#333] rounded-xl px-4 py-2.5 text-white placeholder-zinc-600 text-sm focus:outline-none focus:border-violet-500 transition-colors"
            />
            <button
              onClick={searchUsers}
              className="bg-violet-600 hover:bg-violet-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition-colors"
            >
              Search
            </button>
          </div>

          {searchResults.length > 0 && (
            <div className="mt-3 space-y-2">
              {searchResults.map(user => (
                <div key={user.id} className="flex items-center gap-3 p-2 rounded-xl hover:bg-[#1a1a1a] transition-colors">
                  <div className="w-9 h-9 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold">
                    {(user.display_name || user.username)[0].toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-white">{user.display_name || user.username}</p>
                    <p className="text-xs text-zinc-500">@{user.username}</p>
                  </div>
                  <button
                    onClick={() => sendOrbitRequest(user.id)}
                    className="text-xs bg-violet-600/20 text-violet-400 border border-violet-600/30 px-3 py-1.5 rounded-lg hover:bg-violet-600/30 transition-colors"
                  >
                    + Orbit
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Pending requests */}
        {pendingRequests.length > 0 && (
          <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-4">
            <h2 className="text-sm font-semibold text-zinc-400 mb-3">Pending Requests</h2>
            <div className="space-y-2">
              {pendingRequests.map(orbit => (
                <div key={orbit.id} className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold">
                    {(orbit.user?.display_name || orbit.user?.username || '?')[0].toUpperCase()}
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-white">{orbit.user?.display_name || orbit.user?.username}</p>
                    <p className="text-xs text-zinc-500">@{orbit.user?.username}</p>
                  </div>
                  <button
                    onClick={() => acceptRequest(orbit.id)}
                    className="text-xs bg-green-600/20 text-green-400 border border-green-600/30 px-3 py-1.5 rounded-lg"
                  >
                    Accept
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Friends in orbit */}
        <div className="bg-[#111] border border-[#222] rounded-2xl p-4">
          <h2 className="text-sm font-semibold text-zinc-400 mb-3">Your Orbit</h2>
          {loading ? (
            <div className="flex justify-center py-6">
              <div className="w-5 h-5 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : orbitUsers.length === 0 ? (
            <p className="text-zinc-600 text-sm text-center py-4">No one in your orbit yet. Search above!</p>
          ) : (
            <div className="space-y-2">
              {orbitUsers.map(user => (
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
                  <button
                    onClick={() => startChat(user.id)}
                    className="text-xs bg-[#222] hover:bg-[#2a2a2a] text-zinc-300 px-3 py-1.5 rounded-lg transition-colors"
                  >
                    💬 Chat
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </AppShell>
  );
}
