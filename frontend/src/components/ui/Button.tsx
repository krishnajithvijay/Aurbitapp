import clsx from 'clsx';
import { ButtonHTMLAttributes } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
}

const variants = {
  primary: 'bg-violet-600 hover:bg-violet-700 text-white',
  secondary: 'bg-[#222] hover:bg-[#2a2a2a] text-zinc-300',
  ghost: 'bg-transparent hover:bg-white/5 text-zinc-400 hover:text-white',
  danger: 'bg-red-600/10 hover:bg-red-600/20 border border-red-600/20 text-red-400',
};

const sizes = {
  sm: 'px-3 py-1.5 text-xs rounded-lg',
  md: 'px-4 py-2 text-sm rounded-xl',
  lg: 'px-6 py-3 text-base rounded-xl',
};

export function Button({ variant = 'primary', size = 'md', className, disabled, children, ...props }: ButtonProps) {
  return (
    <button
      {...props}
      disabled={disabled}
      className={clsx(
        'font-medium transition-colors disabled:opacity-40',
        variants[variant],
        sizes[size],
        className
      )}
    >
      {children}
    </button>
  );
}
