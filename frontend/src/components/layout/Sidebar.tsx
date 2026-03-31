'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import clsx from 'clsx';

const navItems = [
  { href: '/feed', label: 'Feed', emoji: '🏠' },
  { href: '/orbit', label: 'Orbit', emoji: '🪐' },
  { href: '/chat', label: 'Messages', emoji: '💬' },
  { href: '/communities', label: 'Communities', emoji: '🏘️' },
  { href: '/notifications', label: 'Notifications', emoji: '🔔' },
  { href: '/profile', label: 'Profile', emoji: '👤' },
];

export function Sidebar() {
  const pathname = usePathname();
  const { profile, signOut } = useAuth();

  return (
    <aside className="hidden md:flex flex-col fixed left-0 top-0 h-full w-64 bg-[#0a0a0a] border-r border-[#1a1a1a] z-40 p-4">
      {/* Logo */}
      <div className="flex items-center gap-3 px-2 py-4 mb-6">
        <div className="w-10 h-10 bg-violet-600 rounded-xl flex items-center justify-center">
          <span className="text-xl">🪐</span>
        </div>
        <span className="text-xl font-bold text-white">Aurbit</span>
      </div>

      {/* Nav items */}
      <nav className="flex-1 space-y-1">
        {navItems.map(item => (
          <Link
            key={item.href}
            href={item.href}
            className={clsx(
              'flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-colors',
              pathname.startsWith(item.href)
                ? 'bg-violet-600/20 text-violet-400'
                : 'text-zinc-400 hover:text-white hover:bg-white/5'
            )}
          >
            <span className="text-lg">{item.emoji}</span>
            {item.label}
          </Link>
        ))}
      </nav>

      {/* User section */}
      {profile && (
        <div className="border-t border-[#1a1a1a] pt-4 mt-4">
          <div className="flex items-center gap-3 px-2 mb-3">
            <div className="w-9 h-9 rounded-full bg-violet-600 flex items-center justify-center text-sm font-bold overflow-hidden">
              {profile.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={profile.avatar_url} alt="" className="w-full h-full object-cover" />
              ) : (
                (profile.display_name || profile.username)[0].toUpperCase()
              )}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">{profile.display_name || profile.username}</p>
              <p className="text-xs text-zinc-500 truncate">@{profile.username}</p>
            </div>
          </div>
          <button
            onClick={signOut}
            className="w-full text-left px-4 py-2 text-sm text-zinc-500 hover:text-red-400 transition-colors rounded-lg hover:bg-red-400/10"
          >
            Sign out
          </button>
        </div>
      )}
    </aside>
  );
}
