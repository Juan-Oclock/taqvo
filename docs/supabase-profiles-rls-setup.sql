-- Supabase Row Level Security (RLS) Policies for Profiles Table
-- Run this in your Supabase SQL Editor

-- 1. Enable RLS on profiles table (if not already enabled)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;

-- 3. Policy: Allow users to INSERT their own profile
CREATE POLICY "Users can insert their own profile"
ON profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 4. Policy: Allow users to UPDATE their own profile
CREATE POLICY "Users can update their own profile"
ON profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 5. Policy: Allow users to SELECT (view) their own profile
CREATE POLICY "Users can view their own profile"
ON profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- 6. Policy: Allow public to view profiles (optional - for leaderboards, etc.)
-- Uncomment this if you want profiles to be publicly viewable
-- CREATE POLICY "Public profiles are viewable by everyone"
-- ON profiles
-- FOR SELECT
-- TO public
-- USING (true);

-- 7. Verify policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'profiles';

-- 8. Test: Check if current user can insert (run this after the policies are created)
-- SELECT auth.uid(); -- This should return your user ID
