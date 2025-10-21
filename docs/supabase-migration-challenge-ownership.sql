-- Migration: Add challenge ownership fields
-- This migration adds the created_by_username field to the challenges table
-- The created_by field should already exist from the original schema

-- Add created_by_username field to challenges table
ALTER TABLE public.challenges 
ADD COLUMN IF NOT EXISTS created_by_username text;

-- Update existing challenges to populate created_by_username from profiles table
-- This will set the username for existing challenges where created_by is not null
UPDATE public.challenges 
SET created_by_username = profiles.username
FROM public.profiles 
WHERE challenges.created_by = profiles.id 
AND challenges.created_by_username IS NULL;

-- Update the RLS policies to ensure proper ownership enforcement
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "challenges_owner_write" ON public.challenges;

-- Recreate the ownership policy with proper permissions
CREATE POLICY "challenges_owner_write" ON public.challenges
  FOR ALL USING (auth.uid() = created_by);

-- Ensure the challenges table has RLS enabled
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

-- Add index for better performance on ownership queries
CREATE INDEX IF NOT EXISTS idx_challenges_created_by ON public.challenges (created_by);

-- Verify the schema
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'challenges' 
AND table_schema = 'public'
ORDER BY ordinal_position;