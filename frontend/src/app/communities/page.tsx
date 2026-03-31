'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { Community } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { useAuth } from '@/context/AuthContext';

const supabase = createClient();

export default function CommunitiesPage() {
  const [communities, setCommunities] = useState<Community[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [creating, setCreating] = useState(false);
  const { supabaseUser } = useAuth();

  useEffect(() => { loadCommunities(); }, []);

  const loadCommunities = async () => {
    const { data } = await supabase
      .from('communities')
      .select('*')
      .order('member_count', { ascending: false });
    setCommunities(data ?? []);
    setLoading(false);
  };

  const createCommunity = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newName.trim() || !supabaseUser) return;
    setCreating(true);
    const { data } = await supabase.from('communities').insert({
      name: newName.trim(),
      description: newDesc.trim() || null,
      created_by: supabaseUser.id,
      is_private: false,
      tags: [],
      created_at: new Date().toISOString(),
    }).select().single();

    if (data) {
      await supabase.from('community_members').insert({
        community_id: data.id,
        user_id: supabaseUser.id,
        role: 'admin',
        joined_at: new Date().toISOString(),
      });
      setNewName('');
      setNewDesc('');
      setShowCreate(false);
      loadCommunities();
    }
    setCreating(false);
  };

  const joinCommunity = async (communityId: string) => {
    if (!supabaseUser) return;
    await supabase.from('community_members').insert({
      community_id: communityId,
      user_id: supabaseUser.id,
      role: 'member',
      joined_at: new Date().toISOString(),
    });
    setCommunities(prev =>
      prev.map(c => c.id === communityId ? { ...c, is_joined: true, member_count: c.member_count + 1 } : c)
    );
  };

  return (
    <AppShell>
      <div>
        <div className="flex items-center justify-between mb-4 pt-2">
          <h1 className="text-xl font-bold text-white">Communities</h1>
          <button
            onClick={() => setShowCreate(!showCreate)}
            className="bg-violet-600 hover:bg-violet-700 text-white text-sm font-medium px-4 py-2 rounded-xl transition-colors"
          >
            + Create
          </button>
        </div>

        {showCreate && (
          <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-4">
            <h2 className="text-sm font-semibold text-white mb-3">Create Community</h2>
            <form onSubmit={createCommunity} className="space-y-3">
              <input
                value={newName}
                onChange={e => setNewName(e.target.value)}
                placeholder="Community name"
                required
                className="w-full bg-[#0a0a0a] border border-[#333] rounded-xl px-4 py-2.5 text-white placeholder-zinc-600 text-sm focus:outline-none focus:border-violet-500"
              />
              <textarea
                value={newDesc}
                onChange={e => setNewDesc(e.target.value)}
                placeholder="Description (optional)"
                rows={2}
                className="w-full bg-[#0a0a0a] border border-[#333] rounded-xl px-4 py-2.5 text-white placeholder-zinc-600 text-sm focus:outline-none focus:border-violet-500 resize-none"
              />
              <div className="flex gap-2">
                <button type="submit" disabled={creating}
                  className="bg-violet-600 hover:bg-violet-700 disabled:opacity-40 text-white text-sm font-medium px-4 py-2 rounded-xl transition-colors">
                  {creating ? 'Creating...' : 'Create'}
                </button>
                <button type="button" onClick={() => setShowCreate(false)}
                  className="bg-[#222] hover:bg-[#2a2a2a] text-zinc-300 text-sm font-medium px-4 py-2 rounded-xl transition-colors">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        {loading ? (
          <div className="flex justify-center py-12">
            <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : communities.length === 0 ? (
          <div className="text-center py-16">
            <span className="text-4xl mb-4 block">🏘️</span>
            <p className="text-zinc-400">No communities yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {communities.map(community => (
              <div key={community.id} className="bg-[#111] border border-[#222] rounded-2xl p-4">
                <div className="flex items-start gap-3">
                  <div className="w-12 h-12 rounded-xl bg-violet-600 flex items-center justify-center text-xl flex-shrink-0">
                    {community.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={community.avatar_url} alt="" className="w-full h-full object-cover rounded-xl" />
                    ) : '🏘️'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <Link href={`/communities/${community.id}`}>
                      <h3 className="font-semibold text-white hover:text-violet-400 transition-colors">
                        {community.name}
                      </h3>
                    </Link>
                    {community.description && (
                      <p className="text-sm text-zinc-400 mt-0.5 line-clamp-2">{community.description}</p>
                    )}
                    <p className="text-xs text-zinc-600 mt-1">
                      {community.member_count} members · {community.post_count} posts
                    </p>
                  </div>
                  <button
                    onClick={() => !community.is_joined && joinCommunity(community.id)}
                    className={`text-sm font-medium px-4 py-1.5 rounded-xl transition-colors flex-shrink-0 ${
                      community.is_joined
                        ? 'bg-[#222] text-zinc-500 cursor-default'
                        : 'bg-violet-600/20 text-violet-400 border border-violet-600/30 hover:bg-violet-600/30'
                    }`}
                  >
                    {community.is_joined ? 'Joined' : 'Join'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </AppShell>
  );
}
