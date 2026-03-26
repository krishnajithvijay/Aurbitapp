# Chat Badge System - Complete Implementation

## Overview
The chat badge system shows unread message counts in two places:
1. **Bottom Navigation** - On the Chat tab icon
2. **Chat Screen** - On individual user chat cards

Both badges are synchronized and update together.

## Badge Flow

### 1. **New Message Received**

```
New Message Arrives
    ↓
Database: messages.is_read = false
    ↓
Badge appears in TWO places simultaneously:
├── Bottom Nav Chat Icon: Shows total unread count
└── Chat Screen User Card: Shows unread count for that user
```

### 2. **Opening Chat from Bottom Navigation**

```
User taps Chat icon (index 4)
    ↓
setState: _unreadMessageCount = 0  ← Badge clears immediately
    ↓
Switch to Chat screen
    ↓
After 100ms: Fetch actual unread count
    ↓
If still unread: Badge reappears with correct count
If no unread: Badge stays hidden
```

### 3. **Opening Individual Chat Conversation**

```
User taps on chat card
    ↓
Optimistic update: Set unreadCount = 0 ← Individual badge clears
    ↓
Navigate to ChatMessageScreen
    ↓
User reads messages
    ↓
Database: Mark messages as read (is_read = true)
    ↓
Return to Chat screen
    ↓
TWO actions happen:
├── Call widget.onMessagesRead() ← Updates bottom nav badge
└── Call _fetchChatUsers()      ← Updates chat screen badges
```

## Implementation Details

### Bottom Navigation Badge (`main_screen.dart`)

**Location**: Top-right corner of Chat icon
**Size**: 14x14 pixels minimum
**Display**: Shows count up to 9, then "9+"
**Color**: 
- Light mode: Black badge with white text
- Dark mode: White badge with black text

**Update Triggers**:
1. App initialization
2. App resume from background
3. Switching to Chat tab
4. Returning from individual chat (via callback)

### Chat Screen Badge (`chat_screen.dart`)

**Location**: Top-right corner of each user's avatar
**Size**: 18x18 pixels
**Display**: Shows actual count
**Color**: Black background with white text

**Update Triggers**:
1. Screen initialization
2. Returning from individual chat
3. Periodic refresh (if implemented)

## Code Implementation

### MainScreen Setup
```dart
class _MainScreenState extends State<MainScreen> {
  int _unreadMessageCount = 0;
  
  List<Widget> get _pages => [
    ChatScreen(onMessagesRead: _fetchUnreadCount), // Pass callback
  ];
  
  void _onTabTapped(int index) {
    if (index == 4) {
      setState(() {
        _currentIndex = index;
        _unreadMessageCount = 0; // Clear immediately
      });
      Future.delayed(Duration(milliseconds: 100), () {
        _fetchUnreadCount(); // Refresh actual count
      });
    }
  }
  
  Future<void> _fetchUnreadCount() async {
    final count = await UserActivityService().getUnreadMessageCount();
    setState(() {
      _unreadMessageCount = count;
    });
  }
}
```

### ChatScreen Setup
```dart
class ChatScreen extends StatefulWidget {
  final VoidCallback? onMessagesRead;
  
  const ChatScreen({this.onMessagesRead});
}

class _ChatScreenState extends State<ChatScreen> {
  void _onChatCardTapped(ChatUser user) async {
    // Optimistically clear badge
    setState(() {
      // Update user's unreadCount to 0
    });
    
    // Open chat
    await Navigator.push(...);
    
    // After returning:
    widget.onMessagesRead?.call(); // Update bottom nav
    _fetchChatUsers();             // Update chat screen
  }
}
```

## User Experience Flow

### Scenario 1: New Message from Alice

```
1. Alice sends message
   → Bottom nav: Chat⁵ (total 5 unread)
   → Chat screen: Alice's card shows (3) badge

2. User taps Chat icon
   → Bottom nav: Chat (badge disappears immediately)
   → Chat screen opens
   → After 100ms: Badge may reappear if still unread

3. User sees Alice has unread messages
   → Alice's card: Shows (3) badge

4. User taps Alice's card
   → Alice's badge: Disappears immediately
   → Opens conversation with Alice

5. User reads messages, presses back
   → Bottom nav: Updates (may show fewer unread)
   → Alice's badge: Stays hidden (messages read)
   → Other users' badges: Remain visible if they have unread
```

### Scenario 2: Multiple Unread Chats

```
Before:
Bottom Nav: Chat⁷
Chat Screen:
  - Alice: (3)
  - Bob: (2)
  - Charlie: (2)

User opens Alice's chat, reads messages:

After:
Bottom Nav: Chat⁴
Chat Screen:
  - Alice: (no badge)
  - Bob: (2)
  - Charlie: (2)
```

## Database Integration

### Counting Unread Messages
```dart
Future<int> getUnreadMessageCount() async {
  final userId = _supabase.auth.currentUser?.id;
  final result = await _supabase
      .from('messages')
      .select('id')
      .eq('receiver_id', userId)
      .eq('is_read', false);
  
  return (result as List).length;
}
```

### Marking Messages as Read
When user opens a conversation, messages are marked as read in the database:
```sql
UPDATE messages 
SET is_read = true 
WHERE receiver_id = 'current_user_id' 
AND sender_id = 'other_user_id'
AND is_read = false;
```

## Synchronization

Both badges are synchronized through:

1. **Shared Data Source**: Same database queries
2. **Callback Mechanism**: Chat screen notifies parent
3. **Immediate Updates**: Optimistic UI updates
4. **Server Refresh**: Final truth from database

## Edge Cases Handled

✅ **Badge shows 0**: Badge is hidden
✅ **User in chat tab**: Bottom badge clears immediately
✅ **User opens specific chat**: Both badges update
✅ **New message while viewing different chat**: Badge appears
✅ **App backgrounded/resumed**: Badges refresh
✅ **Network error**: Graceful fallback (badges may not update)

## Testing Checklist

- [ ] Send message to user → Both badges appear
- [ ] Tap Chat icon → Bottom badge clears immediately
- [ ] Open specific chat → Individual badge clears
- [ ] Read messages → Bottom badge updates to correct count
- [ ] Multiple unread chats → All badges show correctly
- [ ] Background/resume app → Badges refresh
- [ ] No internet → App doesn't crash, badges may be stale

## Performance Considerations

- Badge count queries are lightweight (count only, no message content)
- Optimistic updates provide instant feedback
- Delayed refresh (100ms) prevents UI blocking
- Callback pattern avoids tight coupling

## Future Enhancements

- Real-time updates via Supabase Realtime
- Push notifications integration
- Read receipts
- Message preview in badge tooltip
- Per-conversation notification settings
