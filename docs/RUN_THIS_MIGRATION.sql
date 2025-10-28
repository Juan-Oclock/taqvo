-- ==========================================
-- CRITICAL: Run this in Supabase SQL Editor
-- ==========================================
-- This fixes the like_count and comment_count columns

-- Step 1: Add the columns if they don't exist
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS like_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS comment_count integer DEFAULT 0;

-- Step 2: Set default values for existing activities
UPDATE public.activities 
SET like_count = 0 
WHERE like_count IS NULL;

UPDATE public.activities 
SET comment_count = 0 
WHERE comment_count IS NULL;

-- Step 3: Create the trigger functions
CREATE OR REPLACE FUNCTION update_activity_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.activities 
        SET like_count = like_count + 1 
        WHERE id = NEW.activity_id;
        RAISE NOTICE 'Incremented like_count for activity %', NEW.activity_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.activities 
        SET like_count = GREATEST(0, like_count - 1) 
        WHERE id = OLD.activity_id;
        RAISE NOTICE 'Decremented like_count for activity %', OLD.activity_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_activity_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.activities 
        SET comment_count = comment_count + 1 
        WHERE id = NEW.activity_id;
        RAISE NOTICE 'Incremented comment_count for activity %', NEW.activity_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.activities 
        SET comment_count = GREATEST(0, comment_count - 1) 
        WHERE id = OLD.activity_id;
        RAISE NOTICE 'Decremented comment_count for activity %', OLD.activity_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create the triggers
DROP TRIGGER IF EXISTS trigger_update_like_count ON public.activity_likes;
CREATE TRIGGER trigger_update_like_count
    AFTER INSERT OR DELETE ON public.activity_likes
    FOR EACH ROW EXECUTE FUNCTION update_activity_like_count();

DROP TRIGGER IF EXISTS trigger_update_comment_count ON public.activity_comments;
CREATE TRIGGER trigger_update_comment_count
    AFTER INSERT OR DELETE ON public.activity_comments
    FOR EACH ROW EXECUTE FUNCTION update_activity_comment_count();

-- Step 5: Fix existing counts
UPDATE public.activities a
SET like_count = (
    SELECT COUNT(*) 
    FROM public.activity_likes l 
    WHERE l.activity_id = a.id
);

UPDATE public.activities a
SET comment_count = (
    SELECT COUNT(*) 
    FROM public.activity_comments c 
    WHERE c.activity_id = a.id
);

-- Step 6: Verify
SELECT 
    id, 
    title,
    like_count, 
    comment_count,
    (SELECT COUNT(*) FROM activity_likes WHERE activity_id = activities.id) as actual_likes,
    (SELECT COUNT(*) FROM activity_comments WHERE activity_id = activities.id) as actual_comments
FROM public.activities
WHERE visibility = 'public'
ORDER BY created_at DESC
LIMIT 10;
