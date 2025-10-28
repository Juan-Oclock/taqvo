-- Migration: Add tables for likes and comments
-- Run this in your Supabase SQL Editor

-- Create likes table
CREATE TABLE IF NOT EXISTS public.activity_likes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    activity_id uuid NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE(activity_id, user_id) -- One like per user per activity
);

-- Create comments table
CREATE TABLE IF NOT EXISTS public.activity_comments (
    id uuid PRIMARY KEY,
    activity_id uuid NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username text,
    avatar_url text,
    text text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_likes_activity ON public.activity_likes (activity_id);
CREATE INDEX IF NOT EXISTS idx_likes_user ON public.activity_likes (user_id);
CREATE INDEX IF NOT EXISTS idx_comments_activity ON public.activity_comments (activity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_user ON public.activity_comments (user_id);

-- RLS Policies for likes
ALTER TABLE public.activity_likes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "likes_public_read" ON public.activity_likes;
DROP POLICY IF EXISTS "likes_self_insert" ON public.activity_likes;
DROP POLICY IF EXISTS "likes_self_delete" ON public.activity_likes;

-- Users can read all likes on public activities
CREATE POLICY "likes_public_read" ON public.activity_likes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.activities 
      WHERE id = activity_likes.activity_id 
      AND (visibility = 'public' OR user_id = auth.uid())
    )
  );

-- Users can insert their own likes
CREATE POLICY "likes_self_insert" ON public.activity_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own likes
CREATE POLICY "likes_self_delete" ON public.activity_likes
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for comments
ALTER TABLE public.activity_comments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "comments_public_read" ON public.activity_comments;
DROP POLICY IF EXISTS "comments_self_insert" ON public.activity_comments;
DROP POLICY IF EXISTS "comments_self_delete" ON public.activity_comments;

-- Users can read comments on public activities or their own activities
CREATE POLICY "comments_public_read" ON public.activity_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.activities 
      WHERE id = activity_comments.activity_id 
      AND (visibility = 'public' OR user_id = auth.uid())
    )
  );

-- Users can insert their own comments
CREATE POLICY "comments_self_insert" ON public.activity_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own comments
CREATE POLICY "comments_self_delete" ON public.activity_comments
  FOR DELETE USING (auth.uid() = user_id);

-- Function to update like count
CREATE OR REPLACE FUNCTION update_activity_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.activities 
        SET like_count = like_count + 1 
        WHERE id = NEW.activity_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.activities 
        SET like_count = GREATEST(0, like_count - 1) 
        WHERE id = OLD.activity_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to update comment count
CREATE OR REPLACE FUNCTION update_activity_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.activities 
        SET comment_count = comment_count + 1 
        WHERE id = NEW.activity_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.activities 
        SET comment_count = GREATEST(0, comment_count - 1) 
        WHERE id = OLD.activity_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update counts
DROP TRIGGER IF EXISTS trigger_update_like_count ON public.activity_likes;
CREATE TRIGGER trigger_update_like_count
    AFTER INSERT OR DELETE ON public.activity_likes
    FOR EACH ROW EXECUTE FUNCTION update_activity_like_count();

DROP TRIGGER IF EXISTS trigger_update_comment_count ON public.activity_comments;
CREATE TRIGGER trigger_update_comment_count
    AFTER INSERT OR DELETE ON public.activity_comments
    FOR EACH ROW EXECUTE FUNCTION update_activity_comment_count();

-- Comments
COMMENT ON TABLE public.activity_likes IS 'Stores user likes on activities';
COMMENT ON TABLE public.activity_comments IS 'Stores user comments on activities';
