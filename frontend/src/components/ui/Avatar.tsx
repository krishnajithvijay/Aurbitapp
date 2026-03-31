import clsx from 'clsx';

interface AvatarProps {
  src?: string | null;
  name: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  online?: boolean;
}

const sizeMap = {
  sm: 'w-8 h-8 text-xs',
  md: 'w-10 h-10 text-sm',
  lg: 'w-12 h-12 text-base',
  xl: 'w-16 h-16 text-xl',
};

export function Avatar({ src, name, size = 'md', online }: AvatarProps) {
  return (
    <div className="relative flex-shrink-0">
      <div className={clsx('rounded-full bg-violet-600 flex items-center justify-center font-bold overflow-hidden', sizeMap[size])}>
        {src ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={src} alt={name} className="w-full h-full object-cover" />
        ) : (
          <span className="text-white">{name[0]?.toUpperCase()}</span>
        )}
      </div>
      {online !== undefined && (
        <span className={clsx(
          'absolute bottom-0 right-0 rounded-full border-2 border-black',
          online ? 'bg-green-400' : 'bg-zinc-600',
          size === 'sm' ? 'w-2 h-2' : 'w-2.5 h-2.5'
        )} />
      )}
    </div>
  );
}
