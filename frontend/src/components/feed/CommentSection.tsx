'use client';
import { useState } from 'react';
import { PostComment } from '@/types';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/context/AuthContext';
import { formatDistanceToNow } from 'date-fns';

interface CommentSectionProps {
  postId: string;
  comments: PostComment[];
  onComment?: (comment: PostComment) => void;
}

export function CommentSection({ postId, comments, onComment }: CommentSectionProps) {
  const [newComment, setNewComment] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const { supabaseUser } = useAuth();
  const supabase = createClient();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newComment.trim() || !supabaseUser) return;
    setSubmitting(true);
    const { data } = await supabase.from('post_comments').insert({
      post_id: postId,
      user_id: supabaseUser.id,
      content: newComment.trim(),
      created_at: new Date().toISOString(),
    }).select('*, author:profiles!user_id(*)').single();
    if (data) onComment?.(data);
    setNewComment('');
    setSubmitting(false);
  };

  return (
    <div>
      <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-3">
        <form onSubmit={submit} className="flex gap-3">
          <textarea
            value={newComment}
            onChange={e => setNewComment(e.target.value)}
            placeholder="Add a comment..."
            rows={2}
            className="flex-1 bg-transparent text-white placeholder-zinc-600 text-sm resize-none focus:outline-none"
          />
          <button
            type="submit"
            disabled={!newComment.trim() || submitting}
            className="self-end bg-violet-600 hover:bg-violet-700 disabled:opacity-40 text-white text-sm font-semibold px-4 py-2 rounded-xl transition-colors"
          >
            Post
          </button>
        </form>
      </div>

      <div className="space-y-3">
        {comments.map(comment => (
          <div key={comment.id} className="bg-[#111] border border-[#222] rounded-xl p-3">
            <div className="flex gap-3">
              <div className="w-8 h-8 rounded-full bg-violet-600 flex items-center justify-center text-xs font-bold flex-shrink-0">
                {(comment.author?.display_name || comment.author?.username || 'A')[0].toUpperCase()}
              </div>
              <div>
                <p className="text-sm font-medium text-white">{comment.author?.display_name || comment.author?.username}</p>
                <p className="text-xs text-zinc-500 mb-1">
                  {formatDistanceToNow(new Date(comment.created_at), { addSuffix: true })}
                </p>
                <p className="text-sm text-zinc-300">{comment.content}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
