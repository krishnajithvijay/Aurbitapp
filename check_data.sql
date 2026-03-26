-- Check if we have any tokens
SELECT count(*) FROM user_fcm_tokens;

-- Check if we have any profiles (to use as sender/recipient)
SELECT id, username FROM profiles LIMIT 2;
