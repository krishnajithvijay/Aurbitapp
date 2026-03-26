# UI Flow & User Experience Guide

## 🎨 Visual Flow

### 1. Regular User Experience

```
Community Feed
├── Community Header (with bio if available)
├── Join/Leave Button
├── Members Button (if member)
└── Posts Feed
    └── Each Post shows:
        ├── Username with Verified Badge (if verified)
        ├── Avatar
        └── Post Content

🔹 Join Community Flow:
User clicks "Join" → Check if banned → 
  ├─ If banned: Show Ban Warning Dialog
  │   └── Shows days remaining & reason
  └─ If not banned: Join successfully
```

### 2. Admin User Experience

```
Community Feed
├── Community Header (with bio)
├── Members Button
├── Settings Button (⚙️ Admin Only)
└── Posts Feed

🔹 Settings Flow:
Click Settings → Community Settings Screen
  ├── Edit Community Name
  ├── Edit Community Bio
  └── Save Button

🔹 Members Flow:
Click Members → Community Members Screen
  └── Each Member Card shows:
      ├── Avatar
      ├── Username with Verified Badge
      ├── Role Badge (Admin/Moderator/Member)
      ├── Restriction Badge (if restricted)
      └── Action Menu (⋮) for admins
          ├── Promote to Admin
          ├── Restrict/Unrestrict
          ├── Kick
          └── Ban (20 days)
```

## 🎭 User States

### Member States
1. **Not a Member** → Can join (unless banned)
2. **Regular Member** → Can post, comment, view
3. **Restricted Member** → Can view only, cannot post
4. **Banned** → Cannot join for 20 days
5. **Admin** → Full control over community

### Visual Indicators

#### Verification Badge
```
✅ Blue checkmark next to username
- Visible in: Posts, Comments, Members List, Profile
- Position: Directly after username
- Size: 16px (adjustable)
```

#### Role Badges
```
┌─────────────────┐
│ 🔵 ADMIN        │ Blue background
│ 🟡 MODERATOR    │ Yellow background
│ ⚪ MEMBER       │ Gray background
└─────────────────┘
```

#### Restriction Indicator
```
┌──────────────────────────┐
│ Username            ⚠️   │
│ MEMBER  🟠 RESTRICTED    │ Orange background
└──────────────────────────┘
- Orange border around card
- "RESTRICTED" badge
```

## 📱 Screen Layouts

### Community Settings Screen
```
┌─────────────────────────────┐
│ ← Community Settings   Save │
├─────────────────────────────┤
│                             │
│ ┌─────────────────────────┐ │
│ │ 📝 Community Name       │ │
│ │                         │ │
│ │ [Current Name______]    │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 📄 Community Bio        │ │
│ │                         │ │
│ │ [                     ] │ │
│ │ [Current Bio_________ ] │ │
│ │ [_____________________] │ │
│ │                         │ │
│ │ 0/500 characters        │ │
│ └─────────────────────────┘ │
│                             │
│ ℹ️ Changes visible to all   │
│                             │
└─────────────────────────────┘
```

### Community Members Screen
```
┌─────────────────────────────┐
│ ← Members                   │
├─────────────────────────────┤
│ Pull to refresh...          │
│                             │
│ ┌─────────────────────────┐ │
│ │ 👤 john_doe ✅          │ │
│ │ 🔵 ADMIN            ⋮   │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 👤 jane_smith           │ │
│ │ ⚪ MEMBER 🟠 RESTRICTED ⋮│ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 👤 bob_jones            │ │
│ │ ⚪ MEMBER            ⋮  │ │
│ └─────────────────────────┘ │
│                             │
└─────────────────────────────┘
```

### Admin Action Menu (Bottom Sheet)
```
┌─────────────────────────────┐
│         —————               │
│                             │
│ 🔵 Promote to Admin         │
│                             │
│ 🟡 Restrict Posting         │
│   (or Remove Restriction)   │
│                             │
│ 🔴 Kick from Community      │
│                             │
│ 🔴 Ban (20 days)            │
│                             │
└─────────────────────────────┘
```

### Ban Warning Dialog
```
┌─────────────────────────────┐
│ 🚫 You're Banned            │
├─────────────────────────────┤
│                             │
│ ┌─────────────────────────┐ │
│ │ 📅 14 days remaining    │ │
│ │                         │ │
│ │ Reason:                 │ │
│ │ Spam posting            │ │
│ └─────────────────────────┘ │
│                             │
│ You cannot join this        │
│ community until your        │
│ ban expires.                │
│                             │
│              [Understood]   │
└─────────────────────────────┘
```

## 🔄 User Interaction Flows

### Flow 1: Admin Restricts User
```
1. Admin opens Community Members Screen
2. Admin taps ⋮ on user's card
3. Bottom sheet shows actions
4. Admin taps "Restrict Posting"
5. Dialog asks for reason (optional)
6. Admin confirms
7. User card updates with 🟠 RESTRICTED badge
8. User can no longer create posts
```

### Flow 2: Admin Bans User
```
1. Admin taps "Ban (20 days)" in action menu
2. Dialog asks for reason
3. Admin confirms ban
4. User is removed from community
5. Ban record created in database
6. User tries to rejoin
7. Ban Warning Dialog appears
8. Shows days remaining and reason
```

### Flow 3: User Sees Verified Badge
```
Posts Feed → User posts appear →
  ├─ Verified users: Username ✅
  └─ Regular users: Username

Comments → Each comment shows →
  ├─ Verified: Username ✅
  └─ Regular: Username

Members List → All members →
  └─ Each shows verification status
```

## 🎨 Color Scheme

### Status Colors
- **Admin Badge**: `Colors.blue` (#2196F3)
- **Verified Badge**: `Colors.blue` (#2196F3)
- **Restricted Badge**: `Colors.orange` (#FF9800)
- **Ban Warning**: `Colors.red` (#F44336)
- **Success**: `Colors.green` (#4CAF50)

### Dark Mode
- **Background**: `#121212`
- **Cards**: `#1E1E1E`
- **Text**: `#FFFFFF` / `#FFFFFF70` (70% opacity)

### Light Mode
- **Background**: `#F5F5F5`
- **Cards**: `#FFFFFF`
- **Text**: `#000000` / `#00000087` (87% opacity)

## 📊 Hierarchical Display

### Members List Sorting
1. **First**: Admins
2. **Second**: Moderators
3. **Third**: Regular members (by join date, newest first)

Within each group:
- Restricted members are clearly marked
- Verification badges visible for all

## ⚡ Performance Considerations

### Lazy Loading
- Members list loads in batches
- Pull-to-refresh updates data
- Cached verification status

### Optimistic Updates
- UI updates immediately
- Rollback on failure
- Success/error feedback

## 🔐 Security Visibility

### What Users See
- **Everyone**: Community name, bio, member count
- **Members**: Posts, comments, member list
- **Admins**: Settings, all admin actions

### What's Hidden
- Ban reasons (only to banned user and admins)
- Restriction reasons (only to restricted user and admins)
- Admin action history (future feature)

## 📱 Responsive Design

All screens support:
- Portrait and landscape modes
- Different screen sizes
- Tablet layouts (future)
- Accessibility features

## 🎯 Next Steps for Integration

1. **Run SQL migrations** to update database
2. **Add verification badges** to existing username displays
3. **Add members button** to community feed app bar
4. **Add settings button** (admin only) to app bar
5. **Update join logic** to check for bans
6. **Test all flows** with multiple users
7. **Grant verification** to test users
8. **Create test community** and test all admin actions
