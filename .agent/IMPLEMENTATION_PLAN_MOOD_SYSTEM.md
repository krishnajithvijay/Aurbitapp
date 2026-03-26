# Mood System Implementation Plan

## Overview
Implement a comprehensive mood tracking system that allows users to:
1. Manually select their current mood from the Space Screen
2. Automatically detect and update mood based on emoji usage in posts and chats
3. Display user moods throughout the app (Orbit, Chat, Communities, etc.)

---

## Phase 1: Database Schema Updates

### 1.1 Add Current Mood to Profiles Table
```sql
-- Migration: Add current_mood column to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS current_mood VARCHAR(50) DEFAULT 'Neutral',
ADD COLUMN IF NOT EXISTS mood_updated_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS mood_auto_detected BOOLEAN DEFAULT false;

-- Create index for faster mood queries
CREATE INDEX IF NOT EXISTS idx_profiles_current_mood ON profiles(current_mood);
```

### 1.2 Create Mood History Table (Optional - for analytics)
```sql
CREATE TABLE IF NOT EXISTS mood_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  mood VARCHAR(50) NOT NULL,
  detection_method VARCHAR(20) CHECK (detection_method IN ('manual', 'auto')),
  source_type VARCHAR(20), -- 'post', 'chat', 'manual_selection'
  source_id UUID, -- Reference to post_id or message_id
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mood_history_user_id ON mood_history(user_id);
CREATE INDEX idx_mood_history_created_at ON mood_history(created_at DESC);
```

---

## Phase 2: Backend Services

### 2.1 Create Mood Service (`lib/services/mood_service.dart`)
**Responsibilities:**
- Update user's current mood
- Fetch user's current mood
- Log mood changes to history
- Provide real-time mood updates via Supabase subscriptions

**Key Methods:**
```dart
class MoodService {
  // Manual mood update
  Future<bool> updateMood(String mood, {bool isAutoDetected = false})
  
  // Get current user's mood
  Future<String> getCurrentMood()
  
  // Get another user's mood
  Future<String> getUserMood(String userId)
  
  // Log mood change to history
  Future<void> logMoodChange(String mood, String detectionMethod, {String? sourceType, String? sourceId})
  
  // Subscribe to mood changes (for real-time updates)
  Stream<String> subscribeMoodChanges(String userId)
}
```

### 2.2 Create Emoji Analyzer Service (`lib/services/emoji_analyzer_service.dart`)
**Responsibilities:**
- Analyze text for emojis
- Determine sentiment/mood from emojis
- Return detected mood

**Emoji-to-Mood Mapping:**
```dart
class EmojiAnalyzer {
  static const Map<String, List<String>> emojiToMood = {
    'Happy': ['😊', '😄', '😃', '😁', '🙂', '😀', '🤩', '😍', '🥰', '😇', '🎉', '🎊', '💖', '❤️', '✨'],
    'Sad': ['😢', '😭', '😞', '😔', '🥺', '💔', '😿'],
    'Lonely': ['😶', '😐', '😑', '🌫️', '☁️', '🙁', '😕'],
    'Stressed': ['😰', '😨', '😱', '🤯', '😓', '😩', '💢', '😤'],
    'Tired': ['😴', '🥱', '😪', '💤'],
    'Angry': ['😡', '🤬', '😠', '👿', '💢'],
    'Worried': ['😟', '😧', '😦', '😨', '🙁'],
    'Excited': ['🤩', '😍', '🥳', '🎉', '🎊', '🙌', '👏'],
  };
  
  String? detectMoodFromText(String text);
  List<String> extractEmojis(String text);
  Map<String, int> getMoodScores(List<String> emojis);
  String getDominantMood(Map<String, int> scores);
}
```

---

## Phase 3: UI Components

### 3.1 Mood Selector Widget (`lib/widgets/mood_selector.dart`)
**Design:**
- Bottom sheet modal with grid of mood options
- Each mood has icon, emoji, and label
- Visual feedback on selection
- Smooth animations

**Features:**
- Display current mood
- Allow selection from predefined moods
- Show mood emoji + label
- Haptic feedback on selection
- Auto-dismiss after selection

### 3.2 Current Mood Display Widget (`lib/widgets/current_mood_display.dart`)
**Usage:** Display user's mood across the app
- Small compact version (for lists, cards)
- Large version (for profile, headers)
- Real-time updates via stream

---

## Phase 4: Integration Points

### 4.1 Space Screen
**Changes to `lib/space/space_screen.dart`:**
1. Make "Current mood" row clickable
2. Open mood selector bottom sheet on tap
3. Update displayed mood in real-time
4. Fetch mood from `profiles.current_mood` instead of hardcoded

**Implementation:**
```dart
// Replace static mood display with:
GestureDetector(
  onTap: () => _showMoodSelector(),
  child: Row(
    children: [
      Text('Current mood: ', style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 14)),
      Text(_currentMood, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(width: 4),
      const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
    ],
  ),
)
```

### 4.2 Post Creation
**Changes to post creation screens:**
1. Analyze post content for emojis before submission
2. If mood detected, optionally update user's current mood
3. Show subtle notification: "Mood updated to [X] based on your post"

**Implementation in `create_post_screen.dart` and `create_community_post_screen.dart`:**
```dart
Future<void> _submitPost() async {
  // Existing post creation logic...
  
  // Analyze for mood
  final detectedMood = EmojiAnalyzer().detectMoodFromText(content);
  if (detectedMood != null) {
    await MoodService().updateMood(detectedMood, isAutoDetected: true);
    // Show snackbar notification
  }
}
```

### 4.3 Chat Messages
**Changes to `lib/chat/chat_message_screen.dart`:**
1. Analyze messages for emojis when sent
2. Update mood if emojis detected
3. Optional: Show mood change indicator in chat

**Implementation:**
```dart
Future<void> _sendMessage() async {
  final text = _messageController.text.trim();
  // ... existing send logic
  
  // Analyze mood from message
  final detectedMood = EmojiAnalyzer().detectMoodFromText(text);
  if (detectedMood != null) {
    await MoodService().updateMood(
      detectedMood, 
      isAutoDetected: true,
      sourceType: 'chat',
      sourceId: messageId,
    );
  }
}
```

### 4.4 Display Mood Across App

**Orbit Screen (`lib/orbit/orbit_screen.dart`):**
- Fetch `current_mood` when loading friends
- Display mood emoji next to avatar
- Update query to include `current_mood`

**Chat Screen (`lib/chat/chat_screen.dart`):**
- Already fetches mood from `mood_logs`
- Update to use `current_mood` from profiles instead
- Real-time mood updates

**Communities Screen:**
- Display user's current mood in header
- Same selector as Space screen

**Profile Screen:**
- Show current mood prominently
- Allow mood change from profile

---

## Phase 5: Implementation Steps

### Step 1: Database Migration
1. ✅ Create SQL migration file
2. ✅ Run migration on Supabase
3. ✅ Update RLS policies

### Step 2: Create Services
1. ✅ Implement `MoodService`
2. ✅ Implement `EmojiAnalyzer`
3. ✅ Add unit tests

### Step 3: Create UI Widgets
1. ✅ Build `MoodSelector` widget
2. ✅ Build `CurrentMoodDisplay` widget
3. ✅ Test with various themes

### Step 4: Integrate Manual Selection
1. ✅ Update Space Screen
2. ✅ Update Communities Screen
3. ✅ Update Profile Screen
4. ✅ Test mood persistence

### Step 5: Integrate Auto-Detection
1. ✅ Update post creation screens
2. ✅ Update chat message screen
3. ✅ Add user preference toggle (optional)

### Step 6: Real-time Updates
1. ✅ Add mood subscription streams
2. ✅ Update all screens to listen for mood changes
3. ✅ Test with multiple devices

### Step 7: Testing & Polish
1. ✅ Test all mood transitions
2. ✅ Test emoji detection accuracy
3. ✅ Add loading states
4. ✅ Handle edge cases

---

## Phase 6: Advanced Features (Optional)

### 6.1 Mood Analytics
- Show mood trends over time
- Mood calendar view
- Insights on what affects mood

### 6.2 Smart Mood Suggestions
- AI-based mood suggestions from writing style
- Context-aware mood recommendations

### 6.3 Privacy Settings
- Allow users to hide mood
- Control who can see mood changes

### 6.4 Mood-based Features
- Filter orbit/chat by mood
- Mood-based recommendations
- Community mood atmosphere

---

## Technical Considerations

### Performance
- Cache current mood locally (SharedPreferences)
- Debounce auto-detection (don't update every message)
- Use efficient emoji regex patterns

### UX Considerations
- Don't auto-update mood too frequently (max once per 15 minutes for auto-detection)
- Allow users to opt-out of auto-detection
- Provide undo option for accidental manual changes
- Show timestamp of last mood update

### Error Handling
- Graceful fallback if mood fetch fails
- Default to 'Neutral' if no mood set
- Handle offline scenarios

### Privacy & Security
- Ensure RLS policies protect mood data
- Allow users to hide mood from certain users
- Audit log for mood changes

---

## File Structure
```
lib/
├── services/
│   ├── mood_service.dart          # NEW
│   └── emoji_analyzer_service.dart # NEW
├── widgets/
│   ├── mood_selector.dart          # NEW
│   └── current_mood_display.dart   # NEW
├── space/
│   └── space_screen.dart           # MODIFY
├── community/
│   ├── community_feed_screen.dart  # MODIFY
│   └── create_community_post_screen.dart # MODIFY
├── chat/
│   ├── chat_screen.dart            # MODIFY
│   └── chat_message_screen.dart    # MODIFY
├── orbit/
│   └── orbit_screen.dart           # MODIFY
└── profile/
    └── profile_screen.dart         # MODIFY
```

---

## Rollout Strategy

### Phase 1: Core Functionality (Week 1)
- Database schema
- Mood service
- Manual mood selection
- Basic UI integration

### Phase 2: Auto-Detection (Week 2)
- Emoji analyzer
- Post/chat integration
- Testing & refinement

### Phase 3: Polish & Optimization (Week 3)
- Real-time updates
- Performance optimization
- Bug fixes

### Phase 4: Advanced Features (Future)
- Analytics
- Smart suggestions
- Privacy controls
