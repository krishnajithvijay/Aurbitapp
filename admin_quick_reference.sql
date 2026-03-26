-- Quick Reference SQL Commands for Community Admin & Verification Features
-- Run these commands in Supabase SQL Editor as needed

-- ============================================================================
-- VERIFICATION MANAGEMENT
-- ============================================================================

-- Grant verification to a user by username
SELECT grant_verification(
    (SELECT id FROM profiles WHERE username = 'username_here'),
    'standard'  -- Options: 'standard', 'premium', 'official'
);

-- Grant verification to a user by user ID
SELECT grant_verification('user-uuid-here', 'standard');

-- Revoke verification from a user
SELECT revoke_verification('user-uuid-here');

-- Get all verified users
SELECT id, username, is_verified, verified_at, verification_type
FROM profiles
WHERE is_verified = TRUE
ORDER BY verified_at DESC;

-- Get verification count
SELECT get_verified_users_count();

-- Check if specific user is verified
SELECT is_user_verified('user-uuid-here');

-- ============================================================================
-- COMMUNITY ADMIN OPERATIONS
-- ============================================================================

-- Make a specific user an admin of a community
UPDATE community_members
SET role = 'admin'
WHERE community_id = 'community-uuid-here'
AND user_id = 'user-uuid-here';

-- Remove admin role (demote to member)
UPDATE community_members
SET role = 'member'
WHERE community_id = 'community-uuid-here'
AND user_id = 'user-uuid-here';

-- Get all admins of a community
SELECT cm.*, p.username, p.avatar_url
FROM community_members cm
JOIN profiles p ON cm.user_id = p.id
WHERE cm.community_id = 'community-uuid-here'
AND cm.role = 'admin';

-- Check if user is admin of a community
SELECT is_community_admin('community-uuid-here', 'user-uuid-here');

-- ============================================================================
-- BAN MANAGEMENT
-- ============================================================================

-- Manually ban a user from a community
INSERT INTO community_bans (community_id, user_id, banned_by, reason)
VALUES (
    'community-uuid-here',
    'user-to-ban-uuid',
    'admin-user-uuid',
    'Spam posting'
);

-- Remove a ban (unban user)
DELETE FROM community_bans
WHERE community_id = 'community-uuid-here'
AND user_id = 'user-uuid-here';

-- Get all active bans for a community
SELECT cb.*, p.username
FROM community_bans cb
JOIN profiles p ON cb.user_id = p.id
WHERE cb.community_id = 'community-uuid-here'
AND cb.ban_expires_at > NOW()
ORDER BY cb.banned_at DESC;

-- Get all expired bans
SELECT cb.*, p.username
FROM community_bans cb
JOIN profiles p ON cb.user_id = p.id
WHERE cb.ban_expires_at < NOW()
ORDER BY cb.ban_expires_at DESC;

-- Cleanup expired bans
SELECT cleanup_expired_bans();

-- Check if user is banned from a community
SELECT * FROM is_user_banned('community-uuid-here', 'user-uuid-here');

-- Extend a ban by another 20 days
UPDATE community_bans
SET ban_expires_at = ban_expires_at + INTERVAL '20 days'
WHERE community_id = 'community-uuid-here'
AND user_id = 'user-uuid-here';

-- ============================================================================
-- RESTRICTION MANAGEMENT
-- ============================================================================

-- Restrict a user (prevent posting)
UPDATE community_members
SET 
    is_restricted = TRUE,
    restricted_at = NOW(),
    restricted_by = 'admin-user-uuid',
    restriction_reason = 'Inappropriate content'
WHERE community_id = 'community-uuid-here'
AND user_id = 'user-uuid-here';

-- Remove restriction
UPDATE community_members
SET 
    is_restricted = FALSE,
    restricted_at = NULL,
    restricted_by = NULL,
    restriction_reason = NULL
WHERE community_id = 'community-uuid-here'
AND user_id = 'user-uuid-here';

-- Get all restricted users in a community
SELECT cm.*, p.username, p.avatar_url
FROM community_members cm
JOIN profiles p ON cm.user_id = p.id
WHERE cm.community_id = 'community-uuid-here'
AND cm.is_restricted = TRUE;

-- ============================================================================
-- COMMUNITY MANAGEMENT
-- ============================================================================

-- Update community name and bio
UPDATE communities
SET 
    name = 'New Community Name',
    bio = 'Updated bio text here',
    updated_at = NOW()
WHERE id = 'community-uuid-here';

-- Get community with full details
SELECT 
    c.*,
    (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) as member_count,
    (SELECT COUNT(*) FROM community_posts WHERE community_id = c.id) as post_count
FROM communities c
WHERE c.id = 'community-uuid-here';

-- Get community members with verification status
SELECT * FROM get_community_members_detailed('community-uuid-here');

-- ============================================================================
-- STATISTICS & ANALYTICS
-- ============================================================================

-- Get total members count for a community
SELECT get_community_member_count('community-uuid-here');

-- Get community statistics
SELECT 
    c.name,
    c.bio,
    COUNT(DISTINCT cm.id) as total_members,
    COUNT(DISTINCT CASE WHEN cm.role = 'admin' THEN cm.id END) as admin_count,
    COUNT(DISTINCT CASE WHEN cm.is_restricted = TRUE THEN cm.id END) as restricted_count,
    COUNT(DISTINCT cp.id) as total_posts
FROM communities c
LEFT JOIN community_members cm ON c.id = cm.community_id
LEFT JOIN community_posts cp ON c.id = cp.community_id
WHERE c.id = 'community-uuid-here'
GROUP BY c.id, c.name, c.bio;

-- Get all bans across all communities (system-wide)
SELECT 
    cb.*,
    c.name as community_name,
    p.username as banned_user,
    p2.username as banned_by_user
FROM community_bans cb
JOIN communities c ON cb.community_id = c.id
JOIN profiles p ON cb.user_id = p.id
JOIN profiles p2 ON cb.banned_by = p2.id
WHERE cb.ban_expires_at > NOW()
ORDER BY cb.banned_at DESC;

-- Get most active communities (by member count)
SELECT 
    c.name,
    c.bio,
    COUNT(cm.id) as member_count,
    c.created_at
FROM communities c
LEFT JOIN community_members cm ON c.id = cm.community_id
GROUP BY c.id, c.name, c.bio, c.created_at
ORDER BY member_count DESC
LIMIT 10;

-- ============================================================================
-- BULK OPERATIONS (USE WITH CAUTION)
-- ============================================================================

-- Grant verification to top 10 users by account age
UPDATE profiles
SET is_verified = TRUE, verified_at = NOW(), verification_type = 'standard'
WHERE id IN (
    SELECT id FROM profiles
    WHERE is_verified = FALSE
    ORDER BY created_at ASC
    LIMIT 10
);

-- Remove all restrictions from a community
UPDATE community_members
SET 
    is_restricted = FALSE,
    restricted_at = NULL,
    restricted_by = NULL,
    restriction_reason = NULL
WHERE community_id = 'community-uuid-here'
AND is_restricted = TRUE;

-- ============================================================================
-- UTILITY QUERIES
-- ============================================================================

-- Find user ID by username
SELECT id, username, email FROM profiles WHERE username = 'username_here';

-- Find community ID by name
SELECT id, name, bio FROM communities WHERE name ILIKE '%search_term%';

-- Get user's communities with their roles
SELECT 
    c.name as community_name,
    cm.role,
    cm.is_restricted,
    cm.joined_at
FROM community_members cm
JOIN communities c ON cm.community_id = c.id
WHERE cm.user_id = 'user-uuid-here'
ORDER BY cm.joined_at DESC;

-- Check user's ban status across all communities
SELECT 
    c.name as community_name,
    cb.banned_at,
    cb.ban_expires_at,
    cb.reason,
    EXTRACT(DAY FROM (cb.ban_expires_at - NOW())) as days_remaining
FROM community_bans cb
JOIN communities c ON cb.community_id = c.id
WHERE cb.user_id = 'user-uuid-here'
AND cb.ban_expires_at > NOW();
