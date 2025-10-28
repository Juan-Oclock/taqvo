-- Migration: Add columns for public activity feed
-- This enables displaying activities from other users in the Community feed
-- Run this in your Supabase SQL Editor

-- Add visibility column (public, friends, private)
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS visibility text DEFAULT 'private' CHECK (visibility IN ('public', 'friends', 'private'));

-- Add user profile fields for display
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS username text,
ADD COLUMN IF NOT EXISTS avatar_url text;

-- Add activity metadata fields
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS kind text CHECK (kind IN ('walk', 'run', 'trailRun', 'hiking')),
ADD COLUMN IF NOT EXISTS duration_seconds numeric,
ADD COLUMN IF NOT EXISTS calories numeric,
ADD COLUMN IF NOT EXISTS note text;

-- Add media URLs (for future cloud storage integration)
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS photo_url text,
ADD COLUMN IF NOT EXISTS snapshot_url text;

-- Add social engagement fields
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS like_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS comment_count integer DEFAULT 0;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_activities_visibility ON public.activities (visibility);
CREATE INDEX IF NOT EXISTS idx_activities_created_at ON public.activities (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_user_visibility ON public.activities (user_id, visibility);

-- Update RLS policies to allow reading public activities
-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "activities_self_rw" ON public.activities;
DROP POLICY IF EXISTS "activities_self_read" ON public.activities;
DROP POLICY IF EXISTS "activities_public_read" ON public.activities;
DROP POLICY IF EXISTS "activities_self_insert" ON public.activities;
DROP POLICY IF EXISTS "activities_self_update" ON public.activities;
DROP POLICY IF EXISTS "activities_self_delete" ON public.activities;

-- Allow users to read their own activities
CREATE POLICY "activities_self_read" ON public.activities
  FOR SELECT USING (auth.uid() = user_id);

-- Allow users to read public activities from others
CREATE POLICY "activities_public_read" ON public.activities
  FOR SELECT USING (visibility = 'public');

-- Allow users to insert their own activities
CREATE POLICY "activities_self_insert" ON public.activities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own activities
CREATE POLICY "activities_self_update" ON public.activities
  FOR UPDATE USING (auth.uid() = user_id);

-- Allow users to delete their own activities
CREATE POLICY "activities_self_delete" ON public.activities
  FOR DELETE USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON COLUMN public.activities.visibility IS 'Activity visibility: public (everyone), friends (friends only), private (user only)';
COMMENT ON COLUMN public.activities.username IS 'Cached username of activity creator for display';
COMMENT ON COLUMN public.activities.avatar_url IS 'Cached avatar URL of activity creator for display';
COMMENT ON COLUMN public.activities.kind IS 'Type of activity: walk, run, trailRun, hiking';
COMMENT ON COLUMN public.activities.note IS 'Optional user note about the activity';
COMMENT ON COLUMN public.activities.like_count IS 'Number of likes on this activity';
COMMENT ON COLUMN public.activities.comment_count IS 'Number of comments on this activity';
