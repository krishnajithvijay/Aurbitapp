-- Fix: Drop everything first to ensure clean state
DROP POLICY IF EXISTS "Users can view their own tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert their own tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON user_fcm_tokens;

-- Re-apply policies
CREATE POLICY "Users can view their own tokens"
    ON user_fcm_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tokens"
    ON user_fcm_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tokens"
    ON user_fcm_tokens FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tokens"
    ON user_fcm_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- Explicitly allow service role full access (This helps the Edge Function)
CREATE POLICY "Service role full access"
    ON user_fcm_tokens
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');
