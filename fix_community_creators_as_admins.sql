-- Fix Existing Communities - Add Creators as Admins
-- Run this if you created communities before the fix was applied

-- This script will:
-- 1. Find all communities where the creator is not in community_members
-- 2. Add them as admin members

-- Add creators as admin members for communities where they're missing
INSERT INTO community_members (community_id, user_id, username, role)
SELECT 
    c.id as community_id,
    c.created_by as user_id,
    COALESCE(c.created_by_username, p.username, 'User') as username,
    'admin' as role
FROM communities c
LEFT JOIN profiles p ON c.created_by = p.id
WHERE NOT EXISTS (
    SELECT 1 
    FROM community_members cm 
    WHERE cm.community_id = c.id 
    AND cm.user_id = c.created_by
)
ON CONFLICT (community_id, user_id) DO NOTHING;

-- Verify: Show all community creators and their admin status
SELECT 
    c.name as community_name,
    c.created_by_username as creator,
    cm.role as role_in_members_table,
    CASE 
        WHEN cm.role = 'admin' THEN '✅ Admin'
        WHEN cm.role IS NULL THEN '❌ Not in members table'
        ELSE '⚠️ Member but not admin'
    END as status
FROM communities c
LEFT JOIN community_members cm ON c.id = cm.community_id AND c.created_by = cm.user_id
ORDER BY c.created_at DESC;
