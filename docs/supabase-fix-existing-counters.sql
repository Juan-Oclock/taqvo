-- Fix existing activities to have proper like and comment counts
-- Run this AFTER the main migration to update old activities

-- Ensure like_count and comment_count columns exist and are not null
UPDATE public.activities 
SET like_count = 0 
WHERE like_count IS NULL;

UPDATE public.activities 
SET comment_count = 0 
WHERE comment_count IS NULL;

-- Recalculate like counts for existing activities
UPDATE public.activities a
SET like_count = (
    SELECT COUNT(*) 
    FROM public.activity_likes l 
    WHERE l.activity_id = a.id
);

-- Recalculate comment counts for existing activities
UPDATE public.activities a
SET comment_count = (
    SELECT COUNT(*) 
    FROM public.activity_comments c 
    WHERE c.activity_id = a.id
);

-- Verify the counts
SELECT id, like_count, comment_count, title, visibility
FROM public.activities
WHERE visibility = 'public'
ORDER BY created_at DESC
LIMIT 10;
