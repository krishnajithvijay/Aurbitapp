-- ============================================================
-- AURBIT — COMPLETE SUPABASE SCHEMA
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ────────────────────────────────────────────────────────────
-- PROFILES
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  public_key TEXT,              -- Base64 X25519 public key for E2E
  is_verified BOOLEAN DEFAULT FALSE,
  is_online BOOLEAN DEFAULT FALSE,
  last_seen TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are readable" ON profiles
  FOR SELECT USING (TRUE);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- POSTS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  community_id UUID,
  content TEXT NOT NULL,
  media_url TEXT,
  media_type TEXT,
  likes_count INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Posts are publicly readable" ON posts FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated users can create posts" ON posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own posts" ON posts
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own posts" ON posts
  FOR DELETE USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- POST LIKES
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes readable by all" ON post_likes FOR SELECT USING (TRUE);
CREATE POLICY "Auth users can like" ON post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike" ON post_likes FOR DELETE USING (auth.uid() = user_id);

-- Auto update likes_count
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_like
  AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- ────────────────────────────────────────────────────────────
-- POST COMMENTS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  reply_to_id UUID REFERENCES post_comments(id) ON DELETE SET NULL,
  likes_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Comments readable by all" ON post_comments FOR SELECT USING (TRUE);
CREATE POLICY "Auth users can comment" ON post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments" ON post_comments FOR DELETE USING (auth.uid() = user_id);

-- Auto update comments_count
CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_comment
  AFTER INSERT OR DELETE ON post_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- ────────────────────────────────────────────────────────────
-- COMMUNITIES
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS communities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  banner_url TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  member_count INT DEFAULT 0,
  post_count INT DEFAULT 0,
  is_private BOOLEAN DEFAULT FALSE,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Communities readable by all" ON communities FOR SELECT USING (TRUE);
CREATE POLICY "Auth users can create communities" ON communities
  FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Admins can update communities" ON communities
  FOR UPDATE USING (auth.uid() = created_by);

-- ────────────────────────────────────────────────────────────
-- COMMUNITY MEMBERS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS community_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'moderator', 'admin')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id, user_id)
);

ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members readable by all" ON community_members FOR SELECT USING (TRUE);
CREATE POLICY "Auth users can join" ON community_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave" ON community_members
  FOR DELETE USING (auth.uid() = user_id);

-- Auto update member_count
CREATE OR REPLACE FUNCTION update_community_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE communities SET member_count = member_count + 1 WHERE id = NEW.community_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE communities SET member_count = GREATEST(0, member_count - 1) WHERE id = OLD.community_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_community_member_change
  AFTER INSERT OR DELETE ON community_members
  FOR EACH ROW EXECUTE FUNCTION update_community_member_count();

-- ────────────────────────────────────────────────────────────
-- CHATS (DMs)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant1_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  participant2_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(participant1_id, participant2_id)
);

ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Chat participants can read" ON chats
  FOR SELECT USING (auth.uid() = participant1_id OR auth.uid() = participant2_id);
CREATE POLICY "Auth users can create chats" ON chats
  FOR INSERT WITH CHECK (auth.uid() = participant1_id OR auth.uid() = participant2_id);
CREATE POLICY "Participants can update chat" ON chats
  FOR UPDATE USING (auth.uid() = participant1_id OR auth.uid() = participant2_id);

-- ────────────────────────────────────────────────────────────
-- MESSAGES (E2E Encrypted)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  encrypted_content TEXT,       -- AES-256-GCM ciphertext (base64)
  nonce TEXT,                   -- AES-GCM nonce (base64)
  mac TEXT,                     -- AES-GCM MAC (base64)
  type TEXT DEFAULT 'text' CHECK (type IN ('text','image','audio','video','file','call','system')),
  status TEXT DEFAULT 'sent' CHECK (status IN ('sending','sent','delivered','read','failed')),
  media_url TEXT,
  reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Chat participants can read messages" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chats
      WHERE id = messages.chat_id
      AND (participant1_id = auth.uid() OR participant2_id = auth.uid())
    )
  );
CREATE POLICY "Senders can insert messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Senders can update their messages" ON messages
  FOR UPDATE USING (auth.uid() = sender_id);

-- ────────────────────────────────────────────────────────────
-- ORBITS (friend system)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orbits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requester_id, addressee_id)
);

ALTER TABLE orbits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their orbits" ON orbits
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY "Users can send orbit requests" ON orbits
  FOR INSERT WITH CHECK (auth.uid() = requester_id);
CREATE POLICY "Users can update orbit status" ON orbits
  FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY "Users can delete orbits" ON orbits
  FOR DELETE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- ────────────────────────────────────────────────────────────
-- NOTIFICATIONS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  title TEXT,
  body TEXT,
  reference_id UUID,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert notifications" ON notifications
  FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- FCM TOKENS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  token TEXT NOT NULL,
  platform TEXT CHECK (platform IN ('android', 'ios', 'web')),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own FCM tokens" ON fcm_tokens
  FOR ALL USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- CALL SIGNALS (WebRTC signaling)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS call_signals (
  id TEXT PRIMARY KEY,
  caller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  callee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
  type TEXT DEFAULT 'voice' CHECK (type IN ('voice', 'video')),
  status TEXT DEFAULT 'ringing' CHECK (status IN ('ringing', 'accepted', 'rejected', 'ended', 'missed')),
  sdp_offer TEXT,
  sdp_answer TEXT,
  ice_candidates JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE call_signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Call participants can read signals" ON call_signals
  FOR SELECT USING (auth.uid() = caller_id OR auth.uid() = callee_id);
CREATE POLICY "Callers can insert signals" ON call_signals
  FOR INSERT WITH CHECK (auth.uid() = caller_id);
CREATE POLICY "Call participants can update signals" ON call_signals
  FOR UPDATE USING (auth.uid() = caller_id OR auth.uid() = callee_id);

-- ────────────────────────────────────────────────────────────
-- REALTIME — enable for key tables
-- ────────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE orbits;
ALTER PUBLICATION supabase_realtime ADD TABLE call_signals;
ALTER PUBLICATION supabase_realtime ADD TABLE chats;
ALTER PUBLICATION supabase_realtime ADD TABLE post_likes;
ALTER PUBLICATION supabase_realtime ADD TABLE post_comments;

-- ────────────────────────────────────────────────────────────
-- STORAGE BUCKETS
-- ────────────────────────────────────────────────────────────
-- Run these in Supabase Storage section OR via API:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('post-media', 'post-media', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('community-avatars', 'community-avatars', true);

-- Storage policies (run after creating buckets)
CREATE POLICY "Public avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Auth users can upload avatars" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "Public post media" ON storage.objects FOR SELECT USING (bucket_id = 'post-media');
CREATE POLICY "Auth users can upload post media" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'post-media' AND auth.role() = 'authenticated');

-- ────────────────────────────────────────────────────────────
-- NOTIFICATION TRIGGER — auto-notify on orbit requests
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_orbit_request()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    INSERT INTO notifications (user_id, type, actor_id, reference_id, created_at)
    VALUES (NEW.addressee_id, 'orbit_request', NEW.requester_id, NEW.id, NOW());
  ELSIF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, type, actor_id, reference_id, created_at)
    VALUES (NEW.requester_id, 'orbit_accepted', NEW.addressee_id, NEW.id, NOW());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_orbit_change
  AFTER INSERT OR UPDATE ON orbits
  FOR EACH ROW EXECUTE FUNCTION notify_orbit_request();

-- Notify on post likes
CREATE OR REPLACE FUNCTION notify_post_like()
RETURNS TRIGGER AS $$
DECLARE
  post_owner UUID;
BEGIN
  SELECT user_id INTO post_owner FROM posts WHERE id = NEW.post_id;
  IF post_owner != NEW.user_id THEN
    INSERT INTO notifications (user_id, type, actor_id, reference_id, created_at)
    VALUES (post_owner, 'like', NEW.user_id, NEW.post_id, NOW());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_liked
  AFTER INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION notify_post_like();

-- Notify on post comments
CREATE OR REPLACE FUNCTION notify_post_comment()
RETURNS TRIGGER AS $$
DECLARE
  post_owner UUID;
BEGIN
  SELECT user_id INTO post_owner FROM posts WHERE id = NEW.post_id;
  IF post_owner != NEW.user_id THEN
    INSERT INTO notifications (user_id, type, actor_id, reference_id, created_at)
    VALUES (post_owner, 'comment', NEW.user_id, NEW.post_id, NOW());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_commented
  AFTER INSERT ON post_comments
  FOR EACH ROW EXECUTE FUNCTION notify_post_comment();
