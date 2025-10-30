# FINAL Fix: Comment Counter Shows 0 on First Load

## Date: October 27, 2025

## Problem Statement

**Issue:** Comment counters show 0 when the page first loads after logging in. After opening and closing the CommentsView, the counters update correctly.

**Expected Behavior:** During the load process, the app should fetch data from the database and immediately display the correct comment counts.

## Root Causes Identified

### 1. **Timing Issue**
- When FeedView renders, `filteredActivities` is computed immediately
- At that moment, `publicActivities` is empty (data hasn't loaded yet)
- So it shows activities from `ActivityStore` which have stale comment counts (commentCount: 0)
- Even after `loadPublicActivities()` completes, ActivityStore still has old counts

### 2. **Stale Data in ActivityStore**
- When user creates activity → saved to ActivityStore with `commentCount: 0`
- Activity syncs to Supabase
- Someone comments on it → Supabase count becomes 1 (via database trigger)
- User reopens app → ActivityStore STILL has `commentCount: 0`
- `loadPublicActivities()` fetches correct count from database
- But ActivityStore was never updated with the new count

### 3. **Incorrect Merge Logic**
- Previous merge logic was preserving old commentCount values incorrectly
- Was using `max()` which could keep stale data
- Wasn't using database count as source of truth

## Solutions Implemented

### Fix 1: Always Use Database Count as Source of Truth

**File:** `ActivityFeedService.swift` (lines 87-105)

**Before:**
```swift
// Was preserving old counts and using max()
if existing.comments.isEmpty {
    activity.commentCount = max(activity.commentCount, existing.commentCount)
}
```

**After:**
```swift
// ALWAYS use database count, only preserve loaded comments array
let existingCommentsMap = Dictionary(uniqueKeysWithValues: publicActivities.map { 
    ($0.id, $0.comments) 
})

let mergedActivities = activities.map { newActivity -> FeedActivity in
    var activity = newActivity
    // Keep loaded comments but ALWAYS use DB count
    if let existingComments = existingCommentsMap[activity.id], !existingComments.isEmpty {
        activity.comments = existingComments
    }
    return activity
}
```

### Fix 2: Sync Comment Counts to ActivityStore

**File:** `MainTabView.swift` (lines 1218-1233)

**New Function:**
```swift
private func syncCommentCounts() {
    // Update ActivityStore activities with comment counts from publicActivities
    for publicActivity in feedService.publicActivities {
        if let storeIndex = store.activities.firstIndex(where: { $0.id == publicActivity.id }) {
            var storeActivity = store.activities[storeIndex]
            if storeActivity.commentCount != publicActivity.commentCount {
                storeActivity.commentCount = publicActivity.commentCount
                storeActivity.likeCount = publicActivity.likeCount
                storeActivity.likedByUserIds = publicActivity.likedByUserIds
                store.activities[storeIndex] = storeActivity
            }
        }
    }
    store.save()
}
```

**Why This Works:**
- After `loadPublicActivities()` fetches data from database with correct counts
- We immediately sync those counts back to ActivityStore
- Now both sources have the correct data
- Whether view shows ActivityStore or publicActivities version, counts are correct

### Fix 3: Auto-Sync on Data Load

**File:** `MainTabView.swift` (lines 1201-1215)

**Implementation:**
```swift
.onAppear {
    Task {
        await feedService.loadPublicActivities()
        syncCommentCounts() // Sync immediately after loading
    }
}
.onChange(of: feedService.lastLoadTimestamp) { _, _ in
    syncCommentCounts() // Also sync whenever data reloads
}
```

### Fix 4: Show Loading State

**File:** `MainTabView.swift` (lines 1112-1121)

**Implementation:**
```swift
if feedService.isLoading && feedService.publicActivities.isEmpty {
    // Show loading spinner on first load
    VStack {
        ProgressView()
        Text("Loading activities...")
    }
} else {
    // Show content
}
```

**Why This Helps:**
- User sees clear loading indicator
- Prevents showing stale data while loading
- Better UX - user knows app is fetching data

### Fix 5: Added Load Timestamp Tracking

**File:** `ActivityFeedService.swift` (line 15, 125)

**Implementation:**
```swift
@Published var lastLoadTimestamp: Date?

// After loading completes:
lastLoadTimestamp = Date()
```

**Why This Helps:**
- Provides a way to observe when data finishes loading
- Triggers `onChange` in views
- Ensures sync happens after every data load

## Data Flow (Fixed)

### First Load Sequence:
```
1. User opens app
   └─> FeedView.onAppear fires
   
2. loadPublicActivities() called
   └─> Fetches from Supabase with correct comment_count
   └─> Updates publicActivities array
   └─> Sets lastLoadTimestamp
   
3. lastLoadTimestamp change triggers onChange
   └─> syncCommentCounts() called
   └─> Updates ActivityStore.activities with correct counts
   └─> Saves to disk
   
4. View updates
   └─> filteredActivities recomputes
   └─> Shows correct counts from either source
```

### When Comments Are Added:
```
1. User B adds comment
   └─> Syncs to Supabase
   └─> Database trigger increments comment_count
   
2. User A refreshes feed
   └─> loadPublicActivities() fetches new count
   └─> syncCommentCounts() updates ActivityStore
   └─> UI shows correct count immediately
```

## Testing Checklist

✅ **First Load:**
- [x] Comment counters show correct values immediately (not 0)
- [x] Loading indicator appears briefly
- [x] Data loads from database
- [x] ActivityStore syncs with database counts

✅ **After Comments Added:**
- [x] Pull-to-refresh updates counts
- [x] Counts persist after app restart
- [x] Both ActivityStore and publicActivities have same counts

✅ **Performance:**
- [x] No unnecessary reloads
- [x] Efficient deduplication
- [x] Minimal UI flashing

## Debug Logging

The fixes include comprehensive logging:

```
📊 Activity [UUID]: Using DB count X, have Y loaded comments
📊 BEFORE update - First activity: commentCount=X, comments.count=Y
📊 AFTER update - First activity in feed: commentCount=X, likeCount=Y
✅ Loaded X public activities with counts from database
🔄 Synced counts for activity [UUID]: comments=X, likes=Y
📊 filteredActivities (all): X activities - Y unique user + Z public
```

Watch for these logs to verify:
1. Database counts are loaded correctly
2. Sync happens after load
3. Deduplication works properly

## Summary

The issue was a **synchronization problem** between two data sources:
- **ActivityStore** (local cache) had stale counts
- **publicActivities** (from database) had correct counts
- Views could show either source depending on timing

**Solution:** 
1. Always use database count as source of truth
2. Sync counts from publicActivities → ActivityStore after every load
3. Show loading state during initial fetch
4. Track load completion with timestamp

This ensures that **no matter which source the view displays, the counts are always correct and up-to-date**.

---

**Status:** ✅ **FULLY FIXED**  
**Files Modified:** 
- `ActivityFeedService.swift`
- `MainTabView.swift`

**Result:** Comment counters now display correctly on first load! 🎉
