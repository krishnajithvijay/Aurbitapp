'use client';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Notification } from '@/types';
import { AppShell } from '@/components/layout/AppShell';
import { useAuth } from '@/context/AuthContext';
import { formatDistanceToNow } from 'date-fns';

const notifIcon: Record<string, string> = {
  like: '❤️',
  comment: '💬',
  orbit_request: '🪐',
  orbit_accepted: '✅',
  message: '📩',
  mention: '@',
  default: '🔔',
};

const supabase = createClient();

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
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
      setLoading(false);

      // Mark all as read
      await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', supabaseUser.id)
        .eq('is_read', false);
    };
    load();

    const channel = supabase
      .channel('notifications')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${supabaseUser.id}`,
      }, (payload) => {
        setNotifications(prev => [payload.new as Notification, ...prev]);
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [supabaseUser]);

  return (
    <AppShell>
      <div>
        <div className="flex items-center justify-between mb-4 pt-2">
          <h1 className="text-xl font-bold text-white">Notifications</h1>
        </div>

        {loading ? (
          <div className="flex justify-center py-12">
            <div className="w-6 h-6 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : notifications.length === 0 ? (
          <div className="text-center py-16">
            <span className="text-4xl mb-4 block">🔔</span>
            <p className="text-zinc-400">No notifications yet</p>
          </div>
        ) : (
          <div className="space-y-2">
            {notifications.map(n => (
              <div
                key={n.id}
                className={`flex items-start gap-3 bg-[#111] border rounded-xl p-3 transition-colors ${
                  n.is_read ? 'border-[#222]' : 'border-violet-600/30 bg-violet-600/5'
                }`}
              >
                <span className="text-xl flex-shrink-0">{notifIcon[n.type] ?? notifIcon.default}</span>
                <div className="flex-1 min-w-0">
                  {n.title && <p className="text-sm font-medium text-white">{n.title}</p>}
                  {n.body && <p className="text-sm text-zinc-400">{n.body}</p>}
                  <p className="text-xs text-zinc-600 mt-1">
                    {formatDistanceToNow(new Date(n.created_at), { addSuffix: true })}
                  </p>
                </div>
                {!n.is_read && <div className="w-2 h-2 rounded-full bg-violet-500 flex-shrink-0 mt-1" />}
              </div>
            ))}
          </div>
        )}
      </div>
    </AppShell>
  );
}
