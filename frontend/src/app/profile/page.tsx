'use client';
import { useState } from 'react';
import { useAuth } from '@/context/AuthContext';
import { AppShell } from '@/components/layout/AppShell';
import { formatDistanceToNow } from 'date-fns';

export default function ProfilePage() {
  const { profile, updateProfile, signOut } = useAuth();
  const [editing, setEditing] = useState(false);
  const [displayName, setDisplayName] = useState(profile?.display_name ?? '');
  const [bio, setBio] = useState(profile?.bio ?? '');
  const [saving, setSaving] = useState(false);

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    await updateProfile({ display_name: displayName, bio });
    setSaving(false);
    setEditing(false);
  };

  if (!profile) return null;

  return (
    <AppShell>
      <div>
        <div className="flex items-center justify-between mb-4 pt-2">
          <h1 className="text-xl font-bold text-white">Profile</h1>
          <button
            onClick={() => setEditing(!editing)}
            className="bg-[#222] hover:bg-[#2a2a2a] text-zinc-300 text-sm px-4 py-2 rounded-xl transition-colors"
          >
            {editing ? 'Cancel' : 'Edit'}
          </button>
        </div>

        <div className="bg-[#111] border border-[#222] rounded-2xl p-5 mb-4">
          <div className="flex items-start gap-4">
            <div className="w-20 h-20 rounded-full bg-violet-600 flex items-center justify-center text-3xl font-bold overflow-hidden">
              {profile.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={profile.avatar_url} alt="" className="w-full h-full object-cover" />
              ) : (
                (profile.display_name || profile.username)[0].toUpperCase()
              )}
            </div>
            <div className="flex-1">
              {editing ? (
                <form onSubmit={save} className="space-y-3">
                  <input
                    value={displayName}
                    onChange={e => setDisplayName(e.target.value)}
                    placeholder="Display name"
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-violet-500"
                  />
                  <textarea
                    value={bio}
                    onChange={e => setBio(e.target.value)}
                    placeholder="Bio"
                    rows={3}
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-violet-500 resize-none"
                  />
                  <button type="submit" disabled={saving}
                    className="bg-violet-600 hover:bg-violet-700 disabled:opacity-40 text-white text-sm px-5 py-2 rounded-xl transition-colors">
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                </form>
              ) : (
                <>
                  <h2 className="text-xl font-bold text-white">{profile.display_name || profile.username}</h2>
                  <p className="text-zinc-500 text-sm">@{profile.username}</p>
                  {profile.bio && <p className="text-zinc-300 text-sm mt-2">{profile.bio}</p>}
                  <p className="text-xs text-zinc-600 mt-2">
                    Joined {formatDistanceToNow(new Date(profile.created_at), { addSuffix: true })}
                  </p>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-3 gap-3 mb-4">
          {[['Posts', '0'], ['Orbit', '0'], ['Communities', '0']].map(([label, value]) => (
            <div key={label} className="bg-[#111] border border-[#222] rounded-xl p-3 text-center">
              <p className="text-2xl font-bold text-white">{value}</p>
              <p className="text-xs text-zinc-500">{label}</p>
            </div>
          ))}
        </div>

        {/* E2E Info */}
        <div className="bg-violet-600/10 border border-violet-600/20 rounded-xl p-3 mb-4">
          <p className="text-xs text-violet-400 font-medium">🔐 E2E Encrypted</p>
          <p className="text-xs text-zinc-500 mt-0.5">
            Your messages are end-to-end encrypted with ECDH P-256 + AES-GCM
          </p>
        </div>

        {/* Sign out */}
        <button
          onClick={signOut}
          className="w-full bg-red-600/10 border border-red-600/20 text-red-400 font-medium py-3 rounded-xl hover:bg-red-600/20 transition-colors text-sm"
        >
          Sign Out
        </button>
      </div>
    </AppShell>
  );
}
