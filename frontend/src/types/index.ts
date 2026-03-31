export interface User {
  id: string;
  email: string;
  username: string;
  display_name: string;
  avatar_url?: string;
  bio?: string;
  public_key?: string;
  is_verified: boolean;
  is_online: boolean;
  last_seen?: string;
  created_at: string;
}

export interface Post {
  id: string;
  user_id: string;
  community_id?: string;
  content: string;
  media_url?: string;
  media_type?: string;
  likes_count: number;
  comments_count: number;
  is_liked?: boolean;
  created_at: string;
  author?: User;
}

export interface PostComment {
  id: string;
  post_id: string;
  user_id: string;
  content: string;
  reply_to_id?: string;
  likes_count: number;
  created_at: string;
  author?: User;
}

export interface Community {
  id: string;
  name: string;
  description?: string;
  avatar_url?: string;
  banner_url?: string;
  created_by: string;
  member_count: number;
  post_count: number;
  is_joined?: boolean;
  is_private: boolean;
  tags: string[];
  created_at: string;
}

export interface Chat {
  id: string;
  participant1_id: string;
  participant2_id: string;
  last_message?: Message;
  unread_count: number;
  created_at: string;
  updated_at?: string;
  other_user?: User;
}

export interface Message {
  id: string;
  chat_id: string;
  sender_id: string;
  content?: string;
  encrypted_content?: string;
  nonce?: string;
  mac?: string;
  type: 'text' | 'image' | 'audio' | 'video' | 'file' | 'call' | 'system';
  status: 'sending' | 'sent' | 'delivered' | 'read' | 'failed';
  media_url?: string;
  reply_to_id?: string;
  created_at: string;
  read_at?: string;
  is_deleted: boolean;
}

export interface Orbit {
  id: string;
  requester_id: string;
  addressee_id: string;
  status: 'pending' | 'accepted' | 'blocked';
  created_at: string;
  user?: User;
}

export interface Notification {
  id: string;
  user_id: string;
  type: string;
  actor_id?: string;
  title?: string;
  body?: string;
  reference_id?: string;
  is_read: boolean;
  created_at: string;
  actor?: User;
}
