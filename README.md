# 🪐 Aurbit — Flutter Social App

A full-featured social community platform built with **Flutter + Supabase + Firebase**.

## ✅ Features

| Feature | Status | Tech |
|---|---|---|
| 🔐 Authentication (Email/Password) | ✅ | Supabase Auth |
| 💬 E2E Encrypted Chat | ✅ | X25519 + AES-256-GCM (cryptography pkg) |
| 📞 Voice & Video Calls | ✅ | Supabase Realtime signaling |
| 👥 Orbit (Friend system) | ✅ | Supabase + RLS |
| 🏘️ Communities | ✅ | Supabase |
| 📝 Posts & Feed with likes/comments | ✅ | Supabase + Realtime |
| 🔔 Push Notifications | ✅ | Firebase FCM + flutter_local_notifications |
| 🌙 OLED Dark Theme | ✅ | Material 3 |
| 🎨 Responsive UI | ✅ | Flutter |

---

## 🚀 Quick Setup

### 1. Clone & Install
```bash
git clone <your-repo>
cd aurbitapp
flutter pub get
```

### 2. Supabase
1. Create a project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** → paste and run `supabase/schema.sql`
3. Go to **Storage** → create 3 buckets:
   - `avatars` (public)
   - `post-media` (public)
   - `community-avatars` (public)
4. Copy your **Project URL** and **anon key** from Settings → API

### 3. Configure App
Open `lib/core/constants/app_constants.dart` and replace:
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 4. Firebase (Push Notifications)
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app with package name `com.example.aurbitapp`
3. Download `google-services.json` → place in `android/app/`
4. Add iOS app → download `GoogleService-Info.plist` → place in `ios/Runner/`
5. Enable **Cloud Messaging** in Firebase Console

> **Note:** The app works without Firebase — push notifications will simply be disabled.

### 5. Run
```bash
# Android
flutter run

# iOS
cd ios && pod install && cd ..
flutter run

# Web
flutter run -d chrome
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point
├── core/
│   ├── constants/app_constants.dart   # Supabase config, table names
│   ├── services/
│   │   ├── auth_service.dart          # Auth + profile management
│   │   ├── supabase_service.dart      # DB helper singleton
│   │   ├── encryption_service.dart    # X25519 + AES-256-GCM E2E
│   │   └── notification_service.dart  # FCM + local notifications
│   └── theme/app_theme.dart           # OLED dark theme
├── models/
│   ├── user_model.dart
│   ├── post_model.dart
│   ├── message_model.dart
│   └── community_model.dart           # Also: OrbitModel, NotificationModel
├── screens/
│   ├── splash_screen.dart
│   ├── auth/                          # login_screen, signup_screen
│   ├── home/                          # home_screen (bottom nav)
│   ├── feed/                          # feed, create_post, post_detail
│   ├── chat/                          # chat_list, chat_screen (E2E)
│   ├── calls/                         # call_screen (voice + video)
│   ├── orbit/                         # orbit_screen, new_chat_screen
│   ├── communities/                   # list, detail, create
│   ├── profile/                       # own profile, user profile
│   └── notifications/
└── widgets/
    ├── common/                        # AppButton, AppTextField, UserAvatar
    └── feed/                          # PostCard
```

---

## 🔐 E2E Encryption Architecture

```
Signup:
  1. Generate X25519 keypair on device
  2. Store PRIVATE key in FlutterSecureStorage (never leaves device)
  3. Store PUBLIC key in Supabase profiles.public_key

Send Message:
  1. Fetch recipient's public key from Supabase
  2. Derive shared secret: X25519(myPrivate, theirPublic)
  3. Encrypt: AES-256-GCM(sharedSecret, plaintext) → {ciphertext, nonce, mac}
  4. Store encrypted bytes in Supabase messages table

Receive Message:
  1. Fetch sender's public key from Supabase
  2. Derive same shared secret: X25519(myPrivate, senderPublic)
  3. Decrypt locally — server never sees plaintext
```

---

## 📊 Supabase Schema Summary

| Table | Purpose |
|---|---|
| `profiles` | User accounts + public keys |
| `posts` | Feed posts |
| `post_likes` | Likes (auto-count via trigger) |
| `post_comments` | Comments + nested replies |
| `communities` | Communities |
| `community_members` | Membership + roles |
| `chats` | DM chat rooms |
| `messages` | E2E encrypted messages |
| `orbits` | Friend/follow system |
| `notifications` | In-app notifications |
| `fcm_tokens` | Push notification tokens |
| `call_signals` | WebRTC call signaling |

---

## 🔑 Dependencies

```yaml
supabase_flutter: ^2.8.0       # Backend
firebase_messaging: ^15.1.5    # Push notifications
cryptography: ^2.7.0           # E2E encryption
flutter_secure_storage: ^9.2.2 # Private key storage
flutter_local_notifications    # Local notification display
cached_network_image           # Image caching
image_picker                   # Media uploads
google_fonts                   # Inter font
flutter_animate                # UI animations
shimmer                        # Loading skeletons
timeago                        # Relative timestamps
badges                         # Notification badges
provider                       # State management
```

---

## 🚢 Deployment

### Vercel (Web)
```bash
flutter build web --release
# Upload /build/web to Vercel
```

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### iOS (App Store)
```bash
flutter build ios --release
# Open ios/Runner.xcworkspace in Xcode → Archive → Distribute
```

---

## 🛠️ Extending

### Add a new screen
1. Create `lib/screens/your_feature/your_screen.dart`
2. Add navigation from `home_screen.dart` or relevant entry point

### Add a new table
1. Add SQL to `supabase/schema.sql`
2. Add constant in `app_constants.dart`
3. Create model in `lib/models/`
4. Add service method in relevant service or use `SupabaseService.instance.client` directly

---

## 📝 License
MIT — built with ❤️ using Flutter + Supabase
