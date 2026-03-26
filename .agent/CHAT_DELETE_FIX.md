# Chat Delete Troubleshooting

## Issue: Message Delete Shows Success but Message Doesn't Disappear

### ✅ Quick Fix

**The issue is Row Level Security (RLS) policies in Supabase.**

### Run this in Supabase SQL Editor:

```sql
-- Allow users to delete messages they sent or received
CREATE POLICY IF NOT EXISTS "Users can delete their messages"
ON messages FOR DELETE
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
```

---

## 🔍 How to Diagnose

### Step 1: Check Console Output
After trying to delete a message, you should see:
```
🗑️ Attempting to delete message for everyone: abc-123-xyz
   Message sender: user-id-1, Current user: user-id-1
✅ Delete successful! Result: []
```

### Step 2: Check if Delete Actually Worked
The `Result: []` means **0 rows deleted** - this is the RLS blocking it!

If RLS was not the issue, you'd see an error like:
```
❌ Error deleting message: <actual error>
```

---

## 🛠️ Solutions

### Solution 1: Add RLS Policy (Recommended)

**Go to Supabase Dashboard → SQL Editor → New Query**

```sql
-- Check existing DELETE policies
SELECT * FROM pg_policies 
WHERE tablename = 'messages' AND cmd = 'DELETE';

-- If no DELETE policy exists, create one:
CREATE POLICY "Users can delete conversation messages"
ON messages FOR DELETE
USING (
    auth.uid() = sender_id OR 
    auth.uid() = receiver_id
);
```

### Solution 2: Temporarily Disable RLS (Not Recommended for Production)

```sql
ALTER TABLE messages DISABLE ROW LEVEL SECURITY;
```

⚠️ **Warning**: This makes ALL messages deletable by anyone. Only use for testing!

### Solution 3: Update Existing Policy

If you already have a DELETE policy but it's too restrictive:

```sql
-- Drop old policy
DROP POLICY IF EXISTS "old_policy_name" ON messages;

-- Create new one
CREATE POLICY "Users can delete their messages"
ON messages FOR DELETE
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
```

---

## 📋 Expected Behavior After Fix

### Before Fix:
```
🗑️ Attempting to delete message...
✅ Delete successful! Result: []  ← 0 rows deleted (RLS blocked it)
[Message still visible in chat]
```

### After Fix:
```
🗑️ Attempting to delete message...
✅ Delete successful! Result: [...]  ← Row deleted!
[Message disappears from chat]
```

---

## 🧪 Testing

1. **Delete your own message** → Should work
2. **Delete received message** → Should work
3. **Clear entire chat** → Should work
4. Check console for `✅ Delete successful!` with data in result
5. Message should disappear from UI immediately

---

## 🔐 Recommended RLS Policy

```sql
-- For messages table
CREATE POLICY "Users manage their conversation messages"
ON messages
FOR DELETE
TO authenticated
USING (
    -- User can delete if they sent it or received it
    auth.uid() = sender_id OR 
    auth.uid() = receiver_id
);
```

This allows:
- ✅ Senders to delete their messages ("Delete for Everyone")
- ✅ Receivers to delete messages ("Delete for Me")
- ✅ Both users to participate in "Clear Chat"

---

## 💡 Alternative: Soft Delete

If you want to implement proper "Delete for Me" vs "Delete for Everyone":

### Add column:
```sql
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS deleted_by UUID[] DEFAULT ARRAY[]::UUID[];
```

### Update delete logic:
```dart
// Delete for Me - add user to deleted_by array
await _supabase.from('messages').update({
  'deleted_by': Supabase.instance.client.auth.currentUser!.id
}).eq('id', message.id);

// Delete for Everyone - actual delete
await _supabase.from('messages').delete().eq('id', message.id);
```

### Filter in stream:
```dart
.stream()
.map((messages) => messages.where(
  (m) => !(m['deleted_by'] as List).contains(myId)
).toList())
```

---

## ✅ Checklist

- [ ] Run RLS policy SQL in Supabase
- [ ] Try deleting a message
- [ ] Check console output
- [ ] Verify message disappears
- [ ] Test "Delete for Me"
- [ ] Test "Delete for Everyone"
- [ ] Test "Clear Chat"

---

**TL;DR**: Run the SQL policy creation in Supabase and it will work!
