'use client';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Notification } from '@/types';
import { useAuth } from '@/context/AuthContext';

const supabase = createClient();

export function useNotifications() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const { supabaseUser } = useAuth();

  useEffect(() => {
    if (!supabaseUser) return;

    const load = async () => {
      const { data } = await supabase
        .from('notifications')
        .select('*, actor:profiles!actor_id(*)')
        .eq('user_id', supabaseUser.id)
        .order('created_at', { ascending: false })
        .limit(50);
      setNotifications(data ?? []);
      setUnreadCount((data ?? []).filter((n: Notification) => !n.is_read).length);
      setLoading(false);
    };
    load();

    const channel = supabase
      .channel('notifications-hook')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${supabaseUser.id}` },
        (payload) => {
          setNotifications(prev => [payload.new as Notification, ...prev]);
          setUnreadCount(c => c + 1);
        })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [supabaseUser]);

  const markAllRead = async () => {
    if (!supabaseUser) return;
    await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', supabaseUser.id)
      .eq('is_read', false);
    setUnreadCount(0);
    setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
  };

  return { notifications, unreadCount, loading, markAllRead };
}
