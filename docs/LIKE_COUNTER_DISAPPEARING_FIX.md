# Fix: Like Counter Disappearing When User B Likes

## Date: October 27, 2025

## Problem

**Issue:** 
1. User A likes activity → counter shows "1" ✅
2. User B sees counter showing "1" ✅
3. User B clicks like → counter disappears (shows nothing instead of "2") ❌

**Expected:** Counter should show "2" immediately when User B likes.

## Root Cause

The `handleLike()` function was calling `store.toggleLike()` which does its own optimistic update, causing a **double update conflict**:

### The Buggy Flow:

```
1. User B clicks like
   └─> handleLike() runs
   
2. handleLike() optimistic update
   └─> activity.likeCount = 1 + 1 = 2 ✅
   └─> Updates ActivityStore and feedService ✅
   
3. handleLike() calls store.toggleLike()
   └─> store.toggleLike() reads from ActivityStore
   └─> Finds activity with likeCount = 2 (already updated!)
   └─> Does ANOTHER optimistic update
   └─> Checks if user liked: NO (because it's reading old state)
   └─> Increments again: 2 + 1 = 3 ❌
   └─> OR gets confused and resets to wrong value
   
4. Result: Counter shows wrong value or disappears
```

### Why This Happened

**File:** `MainTabView.swift` (old code)
```swift
// handleLike() was doing optimistic update
updatedActivity.likeCount += 1
store.updateActivity(updatedActivity)

// Then calling store.toggleLike() which ALSO does optimistic update
await store.toggleLike(activityID: activity.id)
```

**File:** `ActivityStore.swift` (line 456-476)
```swift
func toggleLike(activityID: UUID) {
    // This was doing ANOTHER optimistic update!
    var a = activities[idx]
    if wasLiked {
        a.likeCount -= 1
    } else {
        a.likeCount += 1  // Double increment!
    }
}
```

## Solution

**Call Supabase directly** instead of going through `store.toggleLike()`:

### New Flow (Fixed):

```
1. User B clicks like
   └─> handleLike() runs
   
2. handleLike() optimistic update
   └─> activity.likeCount = 1 + 1 = 2 ✅
   └─> Updates ActivityStore and feedService ✅
   └─> UI shows "2" immediately ✅
   
3. handleLike() calls Supabase directly
   └─> supabase.toggleLike() syncs to database
   └─> Database trigger updates like_count
   └─> No double optimistic update!
   
4. Reload from database
   └─> Gets the true count (including all users' likes)
   └─> Syncs to ActivityStore
   └─> UI confirms "2" ✅
```

## Implementation

### File: MainTabView.swift (lines 2529-2574)

```swift
// Update both stores immediately (optimistic)
store.updateActivity(updatedActivity)
feedService.updateActivity(updatedActivity)

print("👍 Optimistic update: likeCount: \(activity.likeCount) → \(updatedActivity.likeCount)")

Task {
    do {
        // Call Supabase DIRECTLY - no double optimistic update
        guard let supabase = SupabaseCommunityDataSource.makeFromInfoPlist(...) else {
            return
        }
        
        // Sync to database
        let isNowLiked = try await supabase.toggleLike(activityID: activity.id)
        print("✅ Like synced to Supabase: isNowLiked: \(isNowLiked)")
        
        // Reload to get server truth (includes other users' likes)
        await feedService.loadPublicActivities()
        
        // Sync back to ActivityStore
        await MainActor.run {
            syncActivityCounts()
        }
    } catch {
        // Rollback on failure
        // ... revert the optimistic update
    }
}
```

### Key Changes

1. **Removed:** Call to `store.toggleLike()`
2. **Added:** Direct call to `supabase.toggleLike()`
3. **Added:** Explicit sync after reload with `syncActivityCounts()`
4. **Added:** Proper rollback on failure
5. **Added:** Better debug logging

## Benefits

### 1. Single Source of Truth
- Only ONE optimistic update happens (in handleLike)
- Database is synced directly
- No conflicting updates

### 2. Immediate UI Update
- Counter shows correct value immediately
- No flashing or disappearing
- Smooth user experience

### 3. Server Confirmation
- After sync, reloads from database
- Gets the TRUE count (including all users)
- Ensures consistency

### 4. Proper Error Handling
- If backend sync fails, rollback happens
- User sees correct state
- No data loss

## Testing Scenarios

### Scenario 1: User B Likes After User A
```
Initial:
- Database: like_count = 1 (User A)
- User B sees: "1"

User B clicks like:
1. Optimistic update: "2" (immediate) ✅
2. Backend sync: INSERT into activity_likes
3. Database trigger: like_count = 2
4. Reload: Gets like_count = 2 from DB
5. Final display: "2" ✅
```

### Scenario 2: Multiple Users Like Simultaneously
```
Initial: like_count = 0

User A clicks like (Device A):
1. Optimistic: "1" ✅
2. Syncs to DB: like_count = 1

User B clicks like (Device B):
1. Optimistic: "1" (doesn't know about A yet) ✅
2. Syncs to DB: like_count = 2
3. Reloads: Gets "2" from DB ✅

User A reloads:
1. Gets like_count = 2 from DB ✅
2. Shows "2" ✅
```

### Scenario 3: Network Failure During Like
```
User clicks like:
1. Optimistic: "2" ✅
2. Backend sync fails ❌
3. Rollback: "1" ✅
4. User sees original count
5. Can retry
```

## Debug Logging

The fix includes comprehensive logging:

```
👍 Optimistic update: activity [UUID] likeCount: 1 → 2, liked: false → true
✅ Like synced to Supabase: activity [UUID] isNowLiked: true
📊 BEFORE update - First activity [UUID]:
   ❤️  likeCount: 2
🔄 Synced activity [UUID]:
   ❤️  Likes: 1 → 2
   👤 My like status: false → true
```

### What to Look For

- ✅ Optimistic update shows correct increment
- ✅ Supabase sync succeeds
- ✅ Reload shows same count
- ✅ Sync confirms the count
- ❌ If you see two increments, there's still a bug

## Summary

**Problem:** Double optimistic update caused like counter to show wrong value or disappear.

**Root Cause:** `handleLike()` was calling `store.toggleLike()` which did its own optimistic update.

**Solution:** Call Supabase directly, avoid double update, sync properly after reload.

**Result:**
- ✅ Counter updates immediately
- ✅ Counter shows correct value
- ✅ Multiple users can like without conflicts
- ✅ Proper error handling with rollback
- ✅ Server truth is enforced after sync

---

**Status:** ✅ **FIXED**  
**File Modified:** `MainTabView.swift`  
**Lines Changed:** 2529-2574

**Technical Approach:** 
- Single optimistic update in UI
- Direct Supabase sync
- Reload + sync for server truth
- Rollback on failure
