'use client';
import { Message } from '@/types';
import { formatDistanceToNow } from 'date-fns';

interface MessageBubbleProps {
  message: Message;
  isMine: boolean;
  text: string;
}

export function MessageBubble({ message, isMine, text }: MessageBubbleProps) {
  return (
    <div className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}>
      <div className={`max-w-[75%] px-4 py-2.5 rounded-2xl text-sm ${
        isMine
          ? 'bg-violet-600 text-white rounded-br-sm'
          : 'bg-[#1a1a1a] text-white rounded-bl-sm border border-[#2a2a2a]'
      }`}>
        <p className="whitespace-pre-wrap break-words">{text}</p>
        <p className={`text-xs mt-1 ${isMine ? 'text-violet-200' : 'text-zinc-600'}`}>
          {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
        </p>
      </div>
    </div>
  );
}
