import clsx from 'clsx';
import { InputHTMLAttributes } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export function Input({ label, error, className, ...props }: InputProps) {
  return (
    <div className="w-full">
      {label && (
        <label className="block text-sm text-zinc-400 mb-1.5">{label}</label>
      )}
      <input
        {...props}
        className={clsx(
          'w-full bg-[#0a0a0a] border rounded-xl px-4 py-3 text-white placeholder-zinc-600 focus:outline-none transition-colors',
          error ? 'border-red-500 focus:border-red-500' : 'border-[#333] focus:border-violet-500',
          className
        )}
      />
      {error && (
        <p className="text-red-400 text-xs mt-1">{error}</p>
      )}
    </div>
  );
}
