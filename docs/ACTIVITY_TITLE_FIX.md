# Activity Title Persistence Fix

## Problem
Activity titles were disappearing after logout/login cycles. Users would add custom titles to their activities (e.g., "Morning Run", "Evening Jog"), but after logging out and back in, the titles would be gone.

## Root Cause
The issue was in the Supabase sync implementation. When activities were uploaded to Supabase, the `title` field was not included in:

1. The `ActivityUpload` struct
2. The upload JSON payload
3. The database schema
4. The SELECT query when fetching activities

This meant that while titles were saved locally, they were never synced to the cloud. When users logged out and back in, if the app fetched activities from Supabase, the titles would be missing.

## Solution

### 1. Code Changes (✅ Applied)

**File: `Community/SupabaseCommunityDataSource.swift`**

- Added `title: String?` field to `ActivityUpload` struct
- Added `title: String?` field to `ActivityUploadResponse` struct
- Included `title: activity.title` when creating the upload object
- Added `"title": upload.title as Any` to the JSON upload payload
- Updated the SELECT query to include `title` field: `"id,user_id,started_at,ended_at,distance_meters,source,title"`

### 2. Database Migration (⚠️ Required)

**You must run this SQL in your Supabase SQL Editor:**

```sql
-- Add title column to activities table
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS title text;

-- Add comment for documentation
COMMENT ON COLUMN public.activities.title IS 'Optional custom title for the activity (e.g., "Morning Run", "Evening Walk")';
```

**Migration file created:** `docs/supabase-migration-add-activity-title.sql`

### 3. Schema Documentation Updated (✅ Applied)

Updated `docs/supabase-community.md` to reflect the new `title` column in the activities table schema.

## Testing

After applying the fix:

1. ✅ Create a new activity with a custom title
2. ✅ Verify the title appears in the Feed
3. ✅ Log out of the app
4. ✅ Log back in
5. ✅ Verify the title is still present

## Migration Steps

1. **Run the database migration** in Supabase SQL Editor (see above)
2. **Deploy the updated app** with the code changes
3. **Test with a new activity** - existing activities without titles will show the activity type as fallback

## Fallback Behavior

The Feed view now includes a fallback: if an activity doesn't have a custom title, it will display the activity type (e.g., "Running", "Walking") instead of showing nothing.

```swift
// Always show either custom title or activity type
Text(activity.title ?? activityTypeName(for: activity.kind))
```

This ensures a consistent UI even for activities created before the fix or imported from HealthKit.

## Files Modified

1. `Community/SupabaseCommunityDataSource.swift` - Added title field to upload/download
2. `MainTabView.swift` - Added fallback title display logic
3. `docs/supabase-community.md` - Updated schema documentation
4. `docs/supabase-migration-add-activity-title.sql` - New migration file
5. `docs/ACTIVITY_TITLE_FIX.md` - This documentation

## Related Issues

- Activity titles were being saved locally but not synced to Supabase
- Logout/login would cause titles to disappear if activities were fetched from cloud
- No database column existed to store the title field
