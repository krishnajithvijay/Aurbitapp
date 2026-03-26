# 🔍 Mood System Troubleshooting Guide

## ❗ Most Common Issue: Database Migration Not Run

### **CRITICAL**: Run this SQL in Supabase first!

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy and paste this SQL:

```sql
-- Add mood columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS current_mood VARCHAR(50) DEFAULT 'Neutral';

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS mood_updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_profiles_current_mood ON profiles(current_mood);
```

4. Click **Run**
5. You should see: "Success. No rows returned"

---

## 🧪 Testing Checklist

### ✅ Check #1: Database Migration
1. Go to Supabase → SQL Editor
2. Run: `SELECT current_mood, mood_updated_at FROM profiles LIMIT 1;`
3. If you get an error "column does not exist" → **Run the migration above**
4. If you see results with "Neutral" → ✅ Database is ready

### ✅ Check #2: Manual Mood Selection
1. Open app → Go to Space screen
2. Tap on "Current mood: Neutral 😐"
3. Select "Happy" from the mood selector
4. Check if it shows "Happy 🤩" 
5. If YES → ✅ Manual selection works
6. If NO → Check console for errors

### ✅ Check #3: Emoji Detection (Single Emoji)
**Note**: Single emoji requires it to be the ONLY mood emoji
1. Go to Chat
2. Send: "test 😂" (just one laughing emoji)
3. Check console for: `📊 Chat mood analysis: [😂] → Happy`
4. Wait 15 seconds, then go back to Space screen
5. Mood should be "Happy 🤩"

### ✅ Check #4: Emoji Detection (Multiple Emojis)
**Better**: Use 2+ emojis for reliable detection
1. Go to Chat
2. Send: "haha 😂😂" or "so happy 😊😁"
3. Check console for: `📊 Chat mood analysis: [😂, 😂] → Happy`
4. Should see: `✅ Mood updated successfully: Happy (auto: true, source: chat)`
5. Go back to Space screen
6. Mood should update to "Happy 🤩"

### ✅ Check #5: Throttling (15-minute rule)
1. Send message with emojis → Mood updates
2. Immediately send another message with different emojis
3. Check console for: `⏸️ Throttle active, skipping mood update`
4. Mood should NOT change
5. Wait 15+ minutes and try again → Should update

---

## 📝 Understanding the Debug Output

### When you send a chat with "😂😂":

```
📊 Chat mood analysis: [😂, 😂] → Happy
🎭 Detected mood from chat: Happy
⏰ Throttle check passed, updating mood...
✅ Mood updated successfully: Happy (auto: true, source: chat)
```

### If throttled (within 15 minutes):
```
📊 Chat mood analysis: [😂, 😂] → Happy
🎭 Detected mood from chat: Happy
⏸️ Throttle active, skipping mood update
```

### If only one emoji (might not detect):
```
📊 Chat mood analysis: [😂] → null
🤷 No clear mood detected from chat message
```

---

## 🎯 Emoji Testing Guide

### Happy Emojis (Will set mood to "Happy")
Try sending: `😂😂` or `😊😁` or `🎉✨`

**All Happy emojis**:
```
😊 😄 😃 😁 🙂 😀 🤩 😍 🥰 😇 
🎉 🎊 💖 ❤️ ✨ 🌟 ⭐ 💕 😻 😺 
🥳 🙌 👏 💪 ✌️ 🤗 😂 🤣 😆 😅 😸 😹
```

### Sad Emojis (Will set mood to "Sad")
Try sending: `😢😭` or `😞😔`

### Tired Emojis
Try sending: `😴💤` or `🥱😴`

### Irritated Emojis  
Try sending: `😤💢` or `😡🤬`

---

## 🐛 Common Issues & Fixes

### Issue 1: "Mood doesn't change at all"
**Fix**: Run the database migration (see top of document)

### Issue 2: "Mood changes manually but not from chat"
**Possible causes**:
- Single emoji (needs 2+ for confidence)
- Wrong emoji (check if it's in the mapping above)
- Throttled (wait 15 minutes)
- Database column missing

**Debug**: 
- Check console output
- Look for `📊 Chat mood analysis` logs
- If you see emojis detected but no update → likely throttled

### Issue 3: "Space screen doesn't show updated mood"
**Fix**: 
- Pull down to refresh (if implemented)
- Or switch to another tab and back
- App now auto-refreshes when you return from background

### Issue 4: "Error: column current_mood does not exist"
**Fix**: You definitely need to run the migration!

### Issue 5: "Only works sometimes"
**Likely**: Throttling in effect
**Check**: Look for `⏸️ Throttle active` in console
**Wait**: 15 minutes between auto-detections

---

## 🔬 Advanced Debugging

### View mood change history in database:
```sql
SELECT current_mood, mood_updated_at 
FROM profiles 
WHERE id = 'your-user-id'
ORDER BY mood_updated_at DESC;
```

### Check if throttle is active:
```sql
SELECT 
  current_mood,
  mood_updated_at,
  (NOW() - mood_updated_at) as time_since_update,
  CASE 
    WHEN (NOW() - mood_updated_at) > INTERVAL '15 minutes' 
    THEN 'Can Update' 
    ELSE 'Throttled' 
  END as status
FROM profiles 
WHERE id = 'your-user-id';
```

### Manually reset throttle (for testing):
```sql
UPDATE profiles 
SET mood_updated_at = NOW() - INTERVAL '20 minutes'
WHERE id = 'your-user-id';
```

---

## ✨ Feature Specification

### Detection Rules:
1. **Minimum emojis**: 2 matching emojis for detection
2. **Exception**: 1 emoji works ONLY if it's the only mood emoji in the message
3. **Throttle**: 15 minutes between auto-updates
4. **Priority**: Manual selection always works (no throttle)

### User Experience:
- **Posts**: Shows notification on mood change
- **Community Posts**: Shows brief notification
- **Chat**: Silent update (no notification)
- **Manual**: Always shows current mood immediately

---

## 📞 Need Help?

1. Check console output for debug emojis (📊 🎭 ✅ ❌ ⏸️)
2. Verify database migration ran successfully
3. Test with 2+ emojis instead of 1
4. Wait 15+ minutes if throttled
5. Try manual mood selection first to verify setup

**Still not working?** Share the console output and I can help debug!
