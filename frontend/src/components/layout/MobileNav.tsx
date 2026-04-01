'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import clsx from 'clsx';

const navItems = [
  { href: '/feed', label: 'Feed', emoji: '🏠' },
  { href: '/orbit', label: 'Orbit', emoji: '🪐' },
  { href: '/chat', label: 'Chat', emoji: '💬' },
  { href: '/communities', label: 'Explore', emoji: '🏘️' },
  { href: '/profile', label: 'Profile', emoji: '👤' },
];

export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-[#0a0a0a] border-t border-[#1a1a1a] z-40 px-2 py-2">
      <div className="flex justify-around">
        {navItems.map(item => (
          <Link
            key={item.href}
            href={item.href}
            className={clsx(
              'flex flex-col items-center gap-1 px-3 py-1.5 rounded-xl text-xs transition-colors',
              pathname.startsWith(item.href)
                ? 'text-violet-400'
                : 'text-zinc-500'
            )}
          >
            <span className="text-xl">{item.emoji}</span>
            <span className="font-medium">{item.label}</span>
          </Link>
        ))}
      </div>
    </nav>
  );
}
