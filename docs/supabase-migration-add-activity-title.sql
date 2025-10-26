-- Migration: Add title column to activities table
-- This fixes the issue where activity titles are lost after logout/login
-- Run this in your Supabase SQL Editor

-- Add title column to activities table
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS title text;

-- Add comment for documentation
COMMENT ON COLUMN public.activities.title IS 'Optional custom title for the activity (e.g., "Morning Run", "Evening Walk")';
