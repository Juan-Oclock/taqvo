# Final Fix: Likes and Comments Synchronization

## Date: October 27, 2025

## Issues Fixed

### 1. ✅ Comment Counters Show 0 on First Load
### 2. ✅ Like Buttons Don't Update Correctly on First Load

## Problem Statement

**Both likes and comments** were not displaying correctly when the page first loads:
- Comment counters showed 0
- Like counts showed 0
- Like button state (heart icon) wasn't red even if user had liked the activity
- Only after opening CommentsView or clicking like button did the UI update

## Root Cause

The app has **two data sources** for activities:
1. **ActivityStore** (local cache) - persisted to disk, loaded immediately
2. **publicActivities** (from Supabase) - fetched from database on app start

**Timeline of the bug:**
1. User creates activity → saved to ActivityStore with `commentCount: 0`, `likeCount: 0`, `likedByUserIds: []`
2. Activity syncs to Supabase database
3. Someone likes/comments → Database counters update via triggers
4. User reopens app → ActivityStore STILL has old counts (0, 0, [])
5. FeedView shows ActivityStore data immediately
6. `loadPublicActivities()` fetches correct data from database BUT doesn't sync back to ActivityStore
7. View shows whichever source it accesses first (usually ActivityStore with stale data)

## Solution Overview

Implemented **bi-directional synchronization** between ActivityStore and publicActivities:

```
Database (Source of Truth)
    ↓
publicActivities (loaded from DB)
    ↓
syncActivityCounts()
    ↓
ActivityStore (updated with DB values)
    ↓
UI displays correct data from either source
```

## Implementation Details

### Fix 1: Always Use Database Count as Source of Truth

**File:** `ActivityFeedService.swift` (lines 87-105)

```swift
// ALWAYS use database count, only preserve loaded comments array
let existingCommentsMap = Dictionary(uniqueKeysWithValues: publicActivities.map { 
    ($0.id, $0.comments) 
})

let mergedActivities = activities.map { newActivity -> FeedActivity in
    var activity = newActivity
    // Keep loaded comments but ALWAYS use DB counts
    if let existingComments = existingCommentsMap[activity.id], !existingComments.isEmpty {
        activity.comments = existingComments
    }
    return activity // Uses DB commentCount, likeCount, likedByUserIds
}
```

**What Changed:**
- Removed logic that preserved old counts with `max()`
- Database counts are ALWAYS used (they're the source of truth)
- Only preserve the full comments array if we've loaded it

### Fix 2: Sync Activity Counts to ActivityStore

**File:** `MainTabView.swift` (lines 1230-1260)

```swift
private func syncActivityCounts() {
    // Update ActivityStore with likes and comment counts from publicActivities
    let currentUserId = SupabaseAuthManager.shared.userId ?? ""
    
    for publicActivity in feedService.publicActivities {
        if let storeActivity = store.activities.first(where: { $0.id == publicActivity.id }) {
            // Check if any counts or like status are different
            let commentsDifferent = storeActivity.commentCount != publicActivity.commentCount
            let likesDifferent = storeActivity.likeCount != publicActivity.likeCount
            let likeStatusDifferent = storeActivity.likedByUserIds != publicActivity.likedByUserIds
            
            if commentsDifferent || likesDifferent || likeStatusDifferent {
                // Create updated activity with synced counts
                var updatedActivity = storeActivity
                updatedActivity.commentCount = publicActivity.commentCount
                updatedActivity.likeCount = publicActivity.likeCount
                updatedActivity.likedByUserIds = publicActivity.likedByUserIds
                
                // Use proper update method (saves to disk automatically)
                store.updateActivity(updatedActivity)
            }
        }
    }
}
```

**What This Does:**
1. After `loadPublicActivities()` fetches from database
2. Loop through all public activities with correct counts
3. Find matching activities in ActivityStore
4. Update ActivityStore activities with database values
5. Save to disk (via `updateActivity()`)
6. Now **both sources have same data**

### Fix 3: Auto-Sync on Data Load

**File:** `MainTabView.swift` (lines 1213-1227)

```swift
.onAppear {
    Task {
        await profileService.loadCurrentUserProfile()
        await feedService.loadPublicActivities() // Load from DB
        syncActivityCounts() // Sync to ActivityStore
    }
}
.onChange(of: feedService.lastLoadTimestamp) { _, _ in
    syncActivityCounts() // Also sync on reload
}
```

**What This Does:**
- When page appears → load from DB → sync
- When data reloads (pull-to-refresh) → sync again
- Ensures ActivityStore is always up-to-date

### Fix 4: Enhanced Debug Logging

**Files:** `ActivityFeedService.swift`, `MainTabView.swift`

```swift
// ActivityFeedService logs:
📊 BEFORE update - First activity [UUID]:
   💬 commentCount: 1
   ❤️  likeCount: 2
   👤 likedByUserIds: ["user-id-1"]
   ✓  Liked by me: true

// MainTabView logs:
🔄 Synced activity [UUID]:
   💬 Comments: 0 → 1
   ❤️  Likes: 0 → 2
   👤 Liked by me: true
```

**What This Shows:**
- Database values loaded correctly
- Sync happened and updated counts
- Like status for current user

## How Likes Work

### Database Structure
```sql
-- activity_likes table
CREATE TABLE activity_likes (
    id uuid PRIMARY KEY,
    activity_id uuid REFERENCES activities(id),
    user_id uuid REFERENCES auth.users(id),
    UNIQUE(activity_id, user_id)
);

-- Trigger automatically updates like_count
CREATE TRIGGER trigger_update_like_count
    AFTER INSERT OR DELETE ON activity_likes
    FOR EACH ROW EXECUTE FUNCTION update_activity_like_count();
```

### Like Data Flow

#### When User Likes Activity:
```
1. User taps heart
   └─> handleLike() called
   
2. Optimistic update (immediate UI)
   └─> Add userId to likedByUserIds array
   └─> Increment likeCount
   └─> Update both ActivityStore and publicActivities
   
3. Backend sync
   └─> store.toggleLike() calls Supabase
   └─> INSERT into activity_likes table
   └─> Database trigger increments like_count
   
4. Reload to confirm
   └─> loadPublicActivities() fetches updated data
   └─> syncActivityCounts() updates ActivityStore
```

#### On Page Load:
```
1. loadPublicActivities() called
   └─> Fetches activities with like_count from DB
   └─> Queries activity_likes for current user's likes
   └─> Populates likedByUserIds array
   
2. syncActivityCounts() called
   └─> Updates ActivityStore with database values
   └─> Like button shows correct state (red heart)
   └─> Like count shows correct number
```

## Testing Checklist

### Comments
✅ **First Load:**
- [x] Comment counters show correct values (not 0)
- [x] Counts persist after app restart
- [x] Sync logs appear in console

✅ **After New Comment:**
- [x] Pull-to-refresh updates counter
- [x] Counter increments correctly
- [x] Both sources show same count

### Likes
✅ **First Load:**
- [x] Like counts show correct values (not 0)
- [x] Heart icon is red if user liked activity
- [x] Heart icon is gray if user hasn't liked
- [x] Counts persist after app restart

✅ **When Liking:**
- [x] Heart turns red immediately (optimistic)
- [x] Count increments immediately
- [x] Syncs to backend
- [x] State persists after reload

✅ **When Unliking:**
- [x] Heart turns gray immediately
- [x] Count decrements immediately
- [x] Syncs to backend
- [x] State persists after reload

✅ **Multiple Users:**
- [x] User A likes → User B sees count increase
- [x] User B likes → count shows 2
- [x] Each user's heart state is independent
- [x] Counts are consistent across users

## Debug Commands

To verify likes are working:

```bash
# Check console for these logs:
grep "📊 BEFORE update" # Shows data from database
grep "🔄 Synced activity" # Shows sync happening
grep "❤️  Likes:" # Shows like counts
grep "👤 Liked by me:" # Shows user's like status
```

## Summary

The solution ensures that:
1. ✅ Database is the **source of truth**
2. ✅ ActivityStore syncs with database on every load
3. ✅ **Both** likes and comments work correctly
4. ✅ UI updates immediately (optimistic) then confirms with server
5. ✅ State persists correctly across app restarts
6. ✅ Multiple users can interact without conflicts

**Result:** Likes and comments now display correctly on first load! 🎉

---

**Status:** ✅ **FULLY FIXED**  
**Files Modified:** 
- `ActivityFeedService.swift`
- `MainTabView.swift`

**Approach:** Bi-directional synchronization between local cache and database
