-- Supabase Challenges Table Setup with RLS
-- Run this in your Supabase SQL Editor

-- 1. Create the challenges table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    detail TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    goal_distance_meters NUMERIC NOT NULL DEFAULT 0,
    is_public BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_by_username TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_dates CHECK (end_date >= start_date),
    CONSTRAINT positive_goal CHECK (goal_distance_meters >= 0)
);

-- 2. Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_challenges_created_by ON challenges(created_by);
CREATE INDEX IF NOT EXISTS idx_challenges_is_public ON challenges(is_public);
CREATE INDEX IF NOT EXISTS idx_challenges_dates ON challenges(start_date, end_date);

-- 3. Enable RLS on challenges table
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;

-- 4. Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS "Public challenges are viewable by everyone" ON challenges;
DROP POLICY IF EXISTS "Users can view their own challenges" ON challenges;
DROP POLICY IF EXISTS "Authenticated users can create challenges" ON challenges;
DROP POLICY IF EXISTS "Users can update their own challenges" ON challenges;
DROP POLICY IF EXISTS "Users can delete their own challenges" ON challenges;

-- 5. Policy: Allow everyone to view public challenges
CREATE POLICY "Public challenges are viewable by everyone"
ON challenges
FOR SELECT
TO public
USING (is_public = true);

-- 6. Policy: Allow users to view their own challenges (even private ones)
CREATE POLICY "Users can view their own challenges"
ON challenges
FOR SELECT
TO authenticated
USING (created_by = auth.uid());

-- 7. Policy: Allow authenticated users to create challenges
CREATE POLICY "Authenticated users can create challenges"
ON challenges
FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

-- 8. Policy: Only the creator can update their own challenges
CREATE POLICY "Users can update their own challenges"
ON challenges
FOR UPDATE
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- 9. Policy: Only the creator can delete their own challenges
CREATE POLICY "Users can delete their own challenges"
ON challenges
FOR DELETE
TO authenticated
USING (created_by = auth.uid());

-- 10. Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_challenges_updated_at ON challenges;
CREATE TRIGGER update_challenges_updated_at
    BEFORE UPDATE ON challenges
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 11. Create challenge_participants table for join tracking
CREATE TABLE IF NOT EXISTS challenge_participants (
    challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    progress_meters NUMERIC DEFAULT 0,
    
    PRIMARY KEY (challenge_id, user_id)
);

-- 12. Enable RLS on challenge_participants
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;

-- 13. Drop existing participant policies
DROP POLICY IF EXISTS "Users can view challenge participants" ON challenge_participants;
DROP POLICY IF EXISTS "Users can join challenges" ON challenge_participants;
DROP POLICY IF EXISTS "Users can leave challenges" ON challenge_participants;
DROP POLICY IF EXISTS "Users can view their own participations" ON challenge_participants;

-- 14. Policy: Anyone can view participants of public challenges
CREATE POLICY "Users can view challenge participants"
ON challenge_participants
FOR SELECT
TO public
USING (
    EXISTS (
        SELECT 1 FROM challenges 
        WHERE challenges.id = challenge_participants.challenge_id 
        AND challenges.is_public = true
    )
);

-- 15. Policy: Users can view their own participations
CREATE POLICY "Users can view their own participations"
ON challenge_participants
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- 16. Policy: Users can join challenges
CREATE POLICY "Users can join challenges"
ON challenge_participants
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- 17. Policy: Users can leave challenges (delete their participation)
CREATE POLICY "Users can leave challenges"
ON challenge_participants
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- 18. Policy: Users can update their own progress
CREATE POLICY "Users can update their own progress"
ON challenge_participants
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 19. Create daily contributions table
CREATE TABLE IF NOT EXISTS challenge_daily_contributions (
    challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    contribution_date DATE NOT NULL,
    distance_meters NUMERIC DEFAULT 0,
    contribution_count INTEGER DEFAULT 0,
    
    PRIMARY KEY (challenge_id, user_id, contribution_date)
);

-- 20. Enable RLS on daily contributions
ALTER TABLE challenge_daily_contributions ENABLE ROW LEVEL SECURITY;

-- 21. Drop existing contribution policies
DROP POLICY IF EXISTS "Users can view contributions for public challenges" ON challenge_daily_contributions;
DROP POLICY IF EXISTS "Users can insert their own contributions" ON challenge_daily_contributions;
DROP POLICY IF EXISTS "Users can update their own contributions" ON challenge_daily_contributions;

-- 22. Policy: Anyone can view contributions for public challenges
CREATE POLICY "Users can view contributions for public challenges"
ON challenge_daily_contributions
FOR SELECT
TO public
USING (
    EXISTS (
        SELECT 1 FROM challenges 
        WHERE challenges.id = challenge_daily_contributions.challenge_id 
        AND challenges.is_public = true
    )
);

-- 23. Policy: Users can insert their own contributions
CREATE POLICY "Users can insert their own contributions"
ON challenge_daily_contributions
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- 24. Policy: Users can update their own contributions
CREATE POLICY "Users can update their own contributions"
ON challenge_daily_contributions
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 25. Verify tables and policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename IN ('challenges', 'challenge_participants', 'challenge_daily_contributions')
ORDER BY tablename, policyname;

-- 26. Test: Check if current user can create a challenge
-- SELECT auth.uid(); -- This should return your user ID

-- 27. Test: Insert a sample challenge (uncomment to test)
-- INSERT INTO challenges (title, detail, start_date, end_date, goal_distance_meters, is_public, created_by, created_by_username)
-- VALUES (
--     'Test Challenge',
--     'This is a test challenge',
--     CURRENT_DATE,
--     CURRENT_DATE + INTERVAL '7 days',
--     5000,
--     true,
--     auth.uid(),
--     'Test User'
-- );
