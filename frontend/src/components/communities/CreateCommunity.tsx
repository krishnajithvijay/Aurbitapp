'use client';
import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/context/AuthContext';

interface CreateCommunityProps {
  onCreated?: () => void;
  onCancel?: () => void;
}

const supabase = createClient();

export function CreateCommunity({ onCreated, onCancel }: CreateCommunityProps) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [creating, setCreating] = useState(false);
  const { supabaseUser } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !supabaseUser) return;
    setCreating(true);

    const { data } = await supabase.from('communities').insert({
      name: name.trim(),
      description: description.trim() || null,
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
      onCreated?.();
    }
    setCreating(false);
  };

  return (
    <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-4">
      <h2 className="text-sm font-semibold text-white mb-3">Create Community</h2>
      <form onSubmit={handleSubmit} className="space-y-3">
        <input
          value={name}
          onChange={e => setName(e.target.value)}
          placeholder="Community name"
          required
          className="w-full bg-[#0a0a0a] border border-[#333] rounded-xl px-4 py-2.5 text-white placeholder-zinc-600 text-sm focus:outline-none focus:border-violet-500"
        />
        <textarea
          value={description}
          onChange={e => setDescription(e.target.value)}
          placeholder="Description (optional)"
          rows={2}
          className="w-full bg-[#0a0a0a] border border-[#333] rounded-xl px-4 py-2.5 text-white placeholder-zinc-600 text-sm focus:outline-none focus:border-violet-500 resize-none"
        />
        <div className="flex gap-2">
          <button type="submit" disabled={creating}
            className="bg-violet-600 hover:bg-violet-700 disabled:opacity-40 text-white text-sm font-medium px-4 py-2 rounded-xl transition-colors">
            {creating ? 'Creating...' : 'Create'}
          </button>
          {onCancel && (
            <button type="button" onClick={onCancel}
              className="bg-[#222] hover:bg-[#2a2a2a] text-zinc-300 text-sm font-medium px-4 py-2 rounded-xl transition-colors">
              Cancel
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
