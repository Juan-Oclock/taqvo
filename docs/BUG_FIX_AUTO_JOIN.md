# Bug Fix: Auto-Join Challenge Issue

## 🐛 Bug Description

**Issue**: When User A creates and joins a challenge, then logs out, User B logs in and sees the challenge as already joined (auto-joined) even though User B never joined it.

**Root Cause**: Join states were stored in `UserDefaults` using shared keys that were not user-specific:
- `"community_join_states"` - Shared across all users
- `"community_club_join_states"` - Shared across all users
- `"community_write_queue"` - Shared across all users

This caused User B to inherit User A's join states when logging in.

---

## ✅ Fix Applied

### **Changes Made** (`CommunityViewModel.swift`)

**1. User-Specific Keys** (lines 65-77):

```swift
// OLD (Shared - WRONG):
private let joinStatesKey = "community_join_states"
private let clubJoinStatesKey = "community_club_join_states"

// NEW (User-Specific - CORRECT):
private var joinStatesKey: String {
    guard let userId = SupabaseAuthManager.shared.userId else {
        return "community_join_states_anonymous"
    }
    return "community_join_states_\(userId)"
}

private var clubJoinStatesKey: String {
    guard let userId = SupabaseAuthManager.shared.userId else {
        return "community_club_join_states_anonymous"
    }
    return "community_club_join_states_\(userId)"
}
```

**2. User-Specific Write Queue** (lines 97-102):

```swift
// OLD (Shared - WRONG):
private let writeQueueKey = "community_write_queue"

// NEW (User-Specific - CORRECT):
private var writeQueueKey: String {
    guard let userId = SupabaseAuthManager.shared.userId else {
        return "community_write_queue_anonymous"
    }
    return "community_write_queue_\(userId)"
}
```

**3. Migration Cleanup** (lines 140-149):

Added automatic cleanup of old shared keys on app launch:

```swift
private func cleanupOldSharedKeys() {
    let oldKeys = ["community_join_states", "community_club_join_states", "community_write_queue"]
    for key in oldKeys {
        if UserDefaults.standard.object(forKey: key) != nil {
            print("DEBUG: Removing old shared key: \(key)")
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
```

---

## 🎯 How It Works Now

### **User A Flow**:
1. User A logs in → `userId = "user-a-id"`
2. User A creates challenge → Auto-joins
3. Join state saved to: `"community_join_states_user-a-id"`
4. User A logs out

### **User B Flow**:
1. User B logs in → `userId = "user-b-id"`
2. User B views challenges
3. Join states loaded from: `"community_join_states_user-b-id"` ✅
4. User B sees challenges as **not joined** (correct!)

### **Key Storage Structure**:

```
UserDefaults:
├─ community_join_states_user-a-id: { "challenge-1": true }
├─ community_join_states_user-b-id: { }  // Empty for User B
├─ community_club_join_states_user-a-id: { }
├─ community_club_join_states_user-b-id: { }
├─ community_write_queue_user-a-id: []
└─ community_write_queue_user-b-id: []
```

---

## 🧪 Testing

### Test Case 1: User A Creates & Joins Challenge

1. **User A** logs in
2. **User A** creates a challenge (auto-joins)
3. Verify: Challenge shows as "Joined" for User A ✅
4. **User A** logs out

### Test Case 2: User B Views Challenge (Should NOT be Joined)

1. **User B** logs in
2. **User B** goes to Community tab
3. **Expected**: Challenge shows "Join Challenge" button ✅
4. **Expected**: Challenge is NOT auto-joined ✅

### Test Case 3: User B Joins Challenge

1. **User B** taps "Join Challenge"
2. **Expected**: Button changes to "Leave Challenge" ✅
3. **User B** logs out
4. **User B** logs back in
5. **Expected**: Challenge still shows as joined for User B ✅

### Test Case 4: User A Still Joined After User B Joins

1. **User A** logs back in
2. **Expected**: Challenge still shows as joined for User A ✅
3. **Expected**: User A's join state is independent of User B ✅

---

## 🔒 Security & Privacy

**Benefits of User-Specific Keys**:
- ✅ Each user has their own join states
- ✅ No data leakage between users
- ✅ Join states persist correctly per user
- ✅ Offline queue is user-specific
- ✅ Automatic cleanup of old shared data

**Anonymous Users**:
- If no user is logged in, keys use `"_anonymous"` suffix
- Anonymous join states are separate from authenticated users
- Prevents conflicts with real user data

---

## 📊 Before vs After

| Scenario | Before (Bug) | After (Fixed) |
|----------|-------------|---------------|
| **User A joins challenge** | Saved to shared key | Saved to User A's key ✅ |
| **User B logs in** | Sees User A's join state ❌ | Sees own join state ✅ |
| **User B joins challenge** | Overwrites User A's state ❌ | Saved to User B's key ✅ |
| **User A logs back in** | Lost join state ❌ | Sees own join state ✅ |

---

## 🚀 Deployment Notes

**Migration**:
- Old shared keys are automatically removed on first launch
- Users will need to re-join challenges (one-time reset)
- This is necessary to fix the data corruption

**Console Output**:
```
DEBUG: Removing old shared key: community_join_states
DEBUG: Removing old shared key: community_club_join_states
DEBUG: Removing old shared key: community_write_queue
```

**User Impact**:
- Existing users will see all challenges as "not joined" after update
- This is expected and correct behavior
- Users can re-join challenges they want to participate in

---

## 📝 Summary

| Component | Status | Details |
|-----------|--------|---------|
| **Bug Identified** | ✅ | Shared UserDefaults keys |
| **Fix Applied** | ✅ | User-specific keys |
| **Migration Added** | ✅ | Auto-cleanup of old keys |
| **Testing Required** | ⚠️ | Test with multiple users |
| **Breaking Change** | ⚠️ | Users need to re-join challenges |

**The bug is now fixed!** Each user's join states are completely isolated from other users. 🎉

---

## 🔍 Related Files

- **Modified**: `/Users/juan_oclock/Documents/ios-mobile/Taqvo/Taqvo/Community/CommunityViewModel.swift`
- **Lines Changed**: 63-149
- **Functions Updated**: 
  - `joinStatesKey` (now computed property)
  - `clubJoinStatesKey` (now computed property)
  - `writeQueueKey` (now computed property)
  - `cleanupOldSharedKeys()` (new migration function)

---

## 💡 Lessons Learned

**Best Practice**: Always include user ID in UserDefaults keys when storing user-specific data:

```swift
// ❌ BAD - Shared across users
private let key = "user_preferences"

// ✅ GOOD - User-specific
private var key: String {
    return "user_preferences_\(userId)"
}
```

This prevents data leakage and ensures proper data isolation between users.
