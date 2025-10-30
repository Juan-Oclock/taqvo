# Fix: Like Status Showing Incorrectly Between Users

## Date: October 27, 2025

## Problem

**Issue:** When User B likes an activity, User A sees the heart icon as enabled (liked) even though User A didn't like it themselves.

**Impact:** Users can't like activities properly because the like button appears already liked when it shouldn't be.

## Root Cause

The `syncActivityCounts()` function was **blindly copying the entire `likedByUserIds` array** from `publicActivities` to `ActivityStore`:

```swift
// WRONG - This overwrites the entire array
updatedActivity.likedByUserIds = publicActivity.likedByUserIds
```

### Why This Was a Problem

The `likedByUserIds` array in `publicActivities` **only contains the current user's ID** (if they liked it), not all users who liked it:

```swift
// In SupabaseCommunityDataSource.swift
if likedActivityIds.contains(updatedActivities[i].id) {
    activity.likedByUserIds = [currentUserId]  // Only current user!
}
```

This is by design because:
1. We don't need to know ALL users who liked an activity
2. We only need to know if the CURRENT user liked it (for the heart icon)
3. The total count comes from `likeCount`

### The Bug Scenario

1. **User A creates activity**
   - ActivityStore: `likedByUserIds = []`, `likeCount = 0`

2. **User B likes the activity**
   - Database: `like_count = 1`
   - Database: `activity_likes` table has entry for User B

3. **User A opens the app**
   - `loadPublicActivities()` fetches from database
   - Since User A hasn't liked it: `likedByUserIds = []` ✅
   - `syncActivityCounts()` syncs to ActivityStore
   - ActivityStore: `likedByUserIds = []` ✅

4. **User A's activity is in both stores**
   - If User A had previously liked their own activity locally
   - ActivityStore: `likedByUserIds = ["user-a-id"]`
   - publicActivities: `likedByUserIds = []` (User A hasn't liked on server)
   - Sync overwrites with `[]` → User A's local like is lost ❌

OR worse:

5. **Data corruption scenario**
   - ActivityStore somehow has: `likedByUserIds = ["user-b-id"]`
   - User A loads, sees User B's ID in the array
   - UI checks if `currentUserId` in array → false (correct)
   - But if sync copies the array incorrectly...

Actually, the real issue is simpler:

### The Real Bug

When syncing, we were copying the **entire** `likedByUserIds` array, which could contain stale or incorrect data. Since `publicActivities` only knows about the current user's like status, we should **only sync the current user's like status**, not overwrite the entire array.

## Solution

**Smart Sync:** Only update the current user's like status in the array, preserve everything else:

```swift
// Get current user's like status from database
let currentUserLikedInPublic = publicActivity.likedByUserIds.contains(currentUserId)

// Start with existing array, remove current user's ID
var newLikedByUserIds = storeActivity.likedByUserIds.filter { $0 != currentUserId }

// Add current user's ID back if they liked it (according to database)
if currentUserLikedInPublic {
    newLikedByUserIds.append(currentUserId)
}

// Update with the new array
updatedActivity.likedByUserIds = newLikedByUserIds
```

### What This Does

1. **Removes current user's ID** from the existing array
2. **Adds it back** only if the database says they liked it
3. **Preserves other user IDs** in the array (if any exist)
4. **Respects the database** as the source of truth for current user

### Example Flow

**Before Fix:**
```
ActivityStore: likedByUserIds = ["user-a-id", "user-c-id"]
publicActivities: likedByUserIds = [] (User A hasn't liked according to DB)

Sync → ActivityStore: likedByUserIds = []  ❌ Lost User A and C's data
```

**After Fix:**
```
ActivityStore: likedByUserIds = ["user-a-id", "user-c-id"]  
publicActivities: likedByUserIds = [] (User A hasn't liked according to DB)

Filter out user-a-id → ["user-c-id"]
Don't add back user-a-id (DB says not liked)
Sync → ActivityStore: likedByUserIds = ["user-c-id"]  ✅ Preserved User C, removed A correctly
```

## Implementation Details

### File: MainTabView.swift (lines 1240-1257)

```swift
// Check if CURRENT USER's like state is different
let currentUserLikedInStore = storeActivity.likedByUserIds.contains(currentUserId)
let currentUserLikedInPublic = publicActivity.likedByUserIds.contains(currentUserId)
let myLikeStatusDifferent = currentUserLikedInStore != currentUserLikedInPublic

if commentsDifferent || likesDifferent || myLikeStatusDifferent {
    // Update likedByUserIds: keep current user's like status from publicActivities
    // This preserves the correct state for the current user only
    var newLikedByUserIds = storeActivity.likedByUserIds.filter { $0 != currentUserId }
    if currentUserLikedInPublic {
        newLikedByUserIds.append(currentUserId)
    }
    updatedActivity.likedByUserIds = newLikedByUserIds
}
```

### Key Changes

1. **Only check current user's status**: Compare if current user's like state differs between store and database
2. **Smart array update**: Filter out current user, add back if needed
3. **Better logging**: Shows before/after state of likedByUserIds array

### Debug Logging

New logs show exactly what's happening:

```
🔄 Synced activity [UUID]:
   💬 Comments: 0 → 1
   ❤️  Likes: 0 → 2
   👤 My like status: false → false
   📋 likedByUserIds: [] → []
```

## Testing Scenarios

### Scenario 1: User B Likes, User A Hasn't
```
Initial:
- ActivityStore (User A): likedByUserIds = []
- publicActivities: likedByUserIds = [] (User A hasn't liked)

Result:
- ActivityStore: likedByUserIds = [] ✅
- Heart icon: Gray ✅
- Like count: 1 ✅
```

### Scenario 2: User A Likes Their Own Activity
```
Initial:
- ActivityStore (User A): likedByUserIds = ["user-a"]
- publicActivities: likedByUserIds = ["user-a"] (User A liked)

Result:
- ActivityStore: likedByUserIds = ["user-a"] ✅
- Heart icon: Red ✅
- Like count: 1 ✅
```

### Scenario 3: User A Unlikes, Then B Likes
```
Initial:
- ActivityStore (User A): likedByUserIds = [] (A unliked)
- publicActivities: likedByUserIds = [] (A hasn't liked)
- Database: like_count = 1 (B liked)

Result:
- ActivityStore: likedByUserIds = [] ✅
- Heart icon: Gray ✅
- Like count: 1 ✅ (shows B's like count but A hasn't liked)
```

### Scenario 4: Both Users Like
```
User A likes:
- ActivityStore: likedByUserIds = ["user-a"]
- Heart: Red ✅

User B likes (different device):
- Database: like_count = 2

User A refreshes:
- publicActivities: likedByUserIds = ["user-a"] (A still liked)
- ActivityStore: likedByUserIds = ["user-a"] (preserved)
- Heart: Red ✅
- Count: 2 ✅
```

## Why This Approach Works

### Database Truth
- Database knows total `like_count` (via triggers)
- Database knows if current user liked it (via query)
- Database is always the source of truth

### Local State
- `likedByUserIds` array is just for UI state (heart icon color)
- We only care if **current user** is in the array
- Other user IDs in the array are irrelevant (but we preserve them)

### Sync Strategy
- Sync `likeCount` from database (total likes)
- Sync **only current user's presence** in `likedByUserIds`
- Don't touch other user IDs in the array
- Result: Correct heart icon state + correct total count

## Summary

**Problem:** Syncing was overwriting the entire `likedByUserIds` array, causing incorrect like states.

**Solution:** Only sync the current user's like status, preserve the rest of the array.

**Result:**
- ✅ User A sees correct heart icon state (based on their own likes)
- ✅ User B's likes don't affect User A's heart icon
- ✅ Like counts are correct for everyone
- ✅ Each user has independent like state

---

**Status:** ✅ **FIXED**  
**File Modified:** `MainTabView.swift`  
**Lines Changed:** 1240-1257
