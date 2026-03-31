'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Post, PostComment } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { PostCard } from '@/components/feed/PostCard';
import { useAuth } from '@/context/AuthContext';
import { formatDistanceToNow } from 'date-fns';

export default function PostDetailPage() {
  const { postId } = useParams<{ postId: string }>();
  const [post, setPost] = useState<Post | null>(null);
  const [comments, setComments] = useState<PostComment[]>([]);
  const [newComment, setNewComment] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const { supabaseUser } = useAuth();
  const supabase = createClient();
  const router = useRouter();

  useEffect(() => {
    const load = async () => {
      const [{ data: postData }, { data: commentsData }] = await Promise.all([
        supabase.from('posts').select('*, author:profiles!user_id(*)').eq('id', postId).single(),
        supabase.from('post_comments').select('*, author:profiles!user_id(*)').eq('post_id', postId).order('created_at'),
      ]);
      setPost(postData);
      setComments(commentsData ?? []);
      setLoading(false);
    };
    load();
  }, [postId]);

  const submitComment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newComment.trim() || !supabaseUser || !post) return;
    setSubmitting(true);
    const { data } = await supabase.from('post_comments').insert({
      post_id: post.id,
      user_id: supabaseUser.id,
      content: newComment.trim(),
      created_at: new Date().toISOString(),
    }).select('*, author:profiles!user_id(*)').single();
    if (data) setComments(prev => [...prev, data]);
    setNewComment('');
    setSubmitting(false);
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
        {post && <PostCard post={post} />}

        <div className="bg-[#111] border border-[#222] rounded-2xl p-4 mb-4">
          <form onSubmit={submitComment} className="flex gap-3">
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
                  <p className="text-sm font-medium text-white">
                    {comment.author?.display_name || comment.author?.username}
                  </p>
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
    </AppShell>
  );
}
