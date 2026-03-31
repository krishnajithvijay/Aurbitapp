# 🪐 Aurbit — Web-First Social App

A full-featured social community platform built with **Next.js + TypeScript + Supabase**.

## ✅ Features

| Feature | Status | Tech |
|---|---|---|
| 🔐 Authentication (Email/Password) | ✅ | Supabase Auth + SSR |
| 💬 E2E Encrypted Chat | ✅ | ECDH P-256 + AES-GCM (Web Crypto API) |
| 📞 Voice & Video Calls | ✅ | Supabase Realtime signaling |
| 👥 Orbit (Friend system) | ✅ | Supabase + RLS |
| 🏘️ Communities | ✅ | Supabase |
| 📝 Posts & Feed with likes/comments | ✅ | Supabase + Realtime |
| 🔔 Push Notifications | ✅ | Backend API + FCM |
| 🌙 OLED Dark Theme | ✅ | Tailwind CSS |
| 🎨 Responsive UI | ✅ | Next.js 14 App Router |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Frontend (Vercel)                  │
│         Next.js 14 + TypeScript + Tailwind CSS       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐  │
│  │   Feed   │ │   Chat   │ │  Orbit   │ │  Comm  │  │
│  └──────────┘ └──────────┘ └──────────┘ └────────┘  │
└───────────────────────┬─────────────────────────────┘
                        │ REST API + Supabase Realtime
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌────────────────┐ ┌──────────────┐
│   Backend     │ │    Supabase    │ │   Supabase   │
│  (Node.js)   │ │  (Auth + DB)   │ │  (Realtime)  │
│  Express API │ │  PostgreSQL    │ │  WebSockets  │
└──────────────┘ └────────────────┘ └──────────────┘
```

---

## 📁 Project Structure

```
├── frontend/           # Next.js 14 + TypeScript + Tailwind CSS
│   └── src/
│       ├── app/        # App Router pages
│       │   ├── (auth)/ # login, signup
│       │   ├── feed/   # Feed + post detail
│       │   ├── chat/   # Chat list + chat room (E2E encrypted)
│       │   ├── orbit/  # Friend system
│       │   ├── communities/ # Browse + detail
│       │   ├── notifications/
│       │   └── profile/
│       ├── components/ # Reusable UI components
│       ├── context/    # AuthContext
│       ├── lib/        # Supabase clients, encryption
│       └── types/      # TypeScript interfaces
│
├── backend/            # Node.js + Express + Supabase
│   └── src/
│       ├── index.ts    # Express app entry point
│       ├── middleware/ # JWT auth
│       ├── lib/        # Supabase admin client
│       └── routes/     # posts, chat, communities, orbit, notifications
│
├── supabase/
│   └── schema.sql      # Database schema
├── vercel.json         # Vercel deployment config (Next.js)
└── .github/
    └── workflows/
        └── deploy.yml  # CI: lint + build + deploy to Vercel
```

---

## 🚀 Quick Setup

### 1. Clone & Install

```bash
git clone <your-repo>
cd aurbitapp

# Frontend
cd frontend && npm install

# Backend
cd ../backend && npm install
```

### 2. Supabase Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** → paste and run `supabase/schema.sql`
3. Go to **Storage** → create 3 buckets:
   - `avatars` (public)
   - `post-media` (public)
   - `community-avatars` (public)
4. Copy your **Project URL**, **anon key**, and **service role key** from Settings → API

### 3. Configure Frontend

```bash
cd frontend
cp .env.example .env.local
```

Edit `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_API_URL=http://localhost:3001
```

### 4. Configure Backend

```bash
cd backend
cp .env.example .env
```

Edit `.env`:
```env
PORT=3001
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
FRONTEND_URL=http://localhost:3000
```

### 5. Run

```bash
# Terminal 1 — Backend
cd backend && npm run dev

# Terminal 2 — Frontend
cd frontend && npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

---

## 🚢 Deployment

### Frontend → Vercel

1. Import project in [vercel.com](https://vercel.com)
2. Set Root Directory to `frontend` (or use `vercel.json` at root)
3. Add environment variables:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `NEXT_PUBLIC_API_URL` (URL of your deployed backend)

For GitHub Actions builds (`.github/workflows/deploy.yml`), add these repository secrets at
**Repository Settings → Secrets and variables → Actions → New repository secret**:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_API_URL`
  - The workflow falls back to safe dummy values (`https://example.supabase.co`, `dev-anon-key`, `http://localhost:3000`) so CI can still build, but you should set real values for any deploy.
4. Deploy — Vercel auto-detects Next.js

### Supabase project (cloud-hosted)

If you are using the provided hosted Supabase project, these public values are available
(anon key is the publishable key shown in Supabase dashboard):

- Project URL: `https://henxsgquexgxvfwngjet.supabase.co`
- Publishable anon key (client-safe): `sb_publishable_Uohn9LqEZ27DRNzljPSZmg_pmeTeghx`
- Database connection: `postgresql://postgres:[YOUR-PASSWORD]@db.henxsgquexgxvfwngjet.supabase.co:5432/postgres`

If you use your own project, replace these with your own values.

To link the repo with this Supabase project using the CLI:
```bash
supabase login        # once per machine
supabase init         # writes supabase/config.toml (already included)
supabase link --project-ref henxsgquexgxvfwngjet
```
Then set env vars:
```bash
# Frontend
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-publishable-anon-key>

# Backend
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

```bash
# Or via CLI
cd frontend && npx vercel --prod
```

### Backend → Railway / Render / Fly.io

The backend is a standard Node.js Express app. Deploy to any Node.js hosting:

**Railway:**
```bash
cd backend
railway init && railway up
```

**Render:**
- Connect GitHub repo
- Root Directory: `backend`
- Build Command: `npm install && npm run build`
- Start Command: `npm start`

**Environment variables** to set on the backend host:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FRONTEND_URL` (your Vercel URL)

---

## 🔐 E2E Encryption Architecture

```
Signup:
  1. Generate ECDH P-256 keypair in browser (Web Crypto API)
  2. Store PRIVATE key in IndexedDB (never leaves device/browser)
  3. Store PUBLIC key in Supabase profiles.public_key

Send Message:
  1. Fetch recipient's public key from Supabase
  2. Derive shared secret: ECDH(myPrivate, theirPublic)
  3. Encrypt: AES-GCM-256(sharedSecret, plaintext) → {ciphertext, nonce}
  4. Store encrypted bytes in Supabase messages table

Receive Message:
  1. Fetch sender's public key from Supabase
  2. Derive same shared secret: ECDH(myPrivate, senderPublic)
  3. Decrypt locally in browser — server never sees plaintext
```

---

## 📊 Supabase Schema

| Table | Purpose |
|---|---|
| `profiles` | User accounts + public keys |
| `posts` | Feed posts |
| `post_likes` | Likes (auto-count via trigger) |
| `post_comments` | Comments + nested replies |
| `communities` | Communities |
| `community_members` | Membership + roles |
| `community_posts` | Posts in communities |
| `chats` | DM chat rooms |
| `messages` | E2E encrypted messages |
| `orbits` | Friend/follow system |
| `notifications` | In-app notifications |
| `fcm_tokens` | Push notification tokens |
| `call_signals` | WebRTC call signaling |

---

## 🔑 Tech Stack

### Frontend
```
next: ^14.x           # React framework + App Router
@supabase/ssr: ^0.5   # SSR-aware Supabase client
tailwindcss: ^3.4     # Utility-first CSS (OLED dark theme)
date-fns: ^3.6        # Date formatting
clsx: ^2.1            # Conditional classes
TypeScript: ^5.5      # Full type safety
```

### Backend
```
express: ^4.19        # HTTP server
@supabase/supabase-js # Admin + user clients
helmet: ^7            # Security headers
cors: ^2.8            # CORS
express-rate-limit    # Rate limiting
morgan: ^1.10         # HTTP logging
TypeScript: ^5.5
```

---

## 📝 License
MIT — built with ❤️ using Next.js + Supabase
