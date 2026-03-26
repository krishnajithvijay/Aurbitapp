# Chat Badge Polling Mechanism

## Overview
Due to the preference against enabling Supabase Realtime (Replication), the application now uses **Periodic Polling** to check for new messages and update unread badges.

## How it Works

The system automatically checks the database every **5 seconds** for new messages. This ensures that badges and chat lists stay updated without user intervention, simulating a real-time experience.

### 1. Main Navigation Badge (`main_screen.dart`)
**Purpose**: Keeps the red badge count on the "Chat" bottom tab icon current.

- **Mechanism**: A `Timer.periodic` runs every 5 seconds.
- **Action**: Calls `_fetchUnreadCount()` which queries the database for the total number of unread messages.
- **Optimization**: Polling pauses when the app is in the background (minimized) to save battery and data, and resumes when the app is reopened.

### 2. Chat List Updates (`chat_screen.dart`)
**Purpose**: Keeps the list of conversations updated with the latest message snippets, timestamps, and individual user unread badges.

- **Mechanism**: A `Timer.periodic` runs every 5 seconds while the Chat Screen is active.
- **Action**: Calls `_fetchChatUsers()` to refresh the entire list.
- **Result**: If a new message arrives from "Alice", her card will jump to the top (if sorted by time), show the new message text, and update the unread badge (e.g., from (2) to (3)).

## Comparison: Realtime vs. Polling

| Feature | Realtime (Replication) | Periodic Polling (Current) |
| :--- | :--- | :--- |
| **Speed** | Immediate (< 100ms) | Delayed (up to 5 sec) |
| **Setup** | Requires Database Toggle | No setup required |
| **Cost** | Free tier supported | Free tier supported |
| **Data Use** | Very Low (Push based) | Slightly Higher (Repeated checks) |

## Configuration

No extra configuration is needed. The polling interval is set to **5 seconds** by default, which provides a good balance between responsiveness and resource usage.

To change the verification frequency, locate `Duration(seconds: 5)` in `main_screen.dart` and `chat_screen.dart`.
