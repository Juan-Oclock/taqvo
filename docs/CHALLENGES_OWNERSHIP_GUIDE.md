# Challenge Ownership & Permissions Guide

## ✅ Current Implementation Status

### **Database Schema**

The challenges system is **already implemented** with proper ownership tracking:

**Challenge Model** (`CommunityViewModel.swift` lines 4-30):
```swift
struct Challenge: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var startDate: Date
    var endDate: Date
    var goalDistanceMeters: Double
    var isJoined: Bool
    var progressMeters: Double
    var isPublic: Bool
    var createdBy: UUID?           // ✅ Tracks challenge creator
    var createdByUsername: String? // ✅ Displays creator name
}
```

### **Supabase Table Structure**

**Table**: `challenges`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `title` | TEXT | Challenge title |
| `detail` | TEXT | Challenge description |
| `start_date` | DATE | Start date |
| `end_date` | DATE | End date |
| `goal_distance_meters` | NUMERIC | Goal distance |
| `is_public` | BOOLEAN | Public/private flag |
| **`created_by`** | UUID | **Creator's user ID** ✅ |
| **`created_by_username`** | TEXT | **Creator's username** ✅ |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

---

## 🔐 Permission Rules (Already Implemented)

### **Client-Side Checks**

**Location**: `CommunityViewModel.swift` lines 312-320

```swift
func canModifyChallenge(_ challenge: Challenge) -> Bool {
    guard let currentUserId = getCurrentUserId() else { return false }
    return challenge.createdBy == currentUserId  // ✅ Only creator can modify
}

func canDeleteChallenge(_ challenge: Challenge) -> Bool {
    return canModifyChallenge(challenge)  // ✅ Only creator can delete
}
```

### **Server-Side RLS Policies** (Need to be set up)

Run `supabase-challenges-setup.sql` to enable:

1. **View Permissions**:
   - ✅ Everyone can view public challenges
   - ✅ Users can view their own private challenges

2. **Create Permissions**:
   - ✅ Any authenticated user can create challenges
   - ✅ `created_by` must match `auth.uid()`

3. **Update Permissions**:
   - ✅ **Only the creator** can update their challenges
   - ✅ Enforced by: `created_by = auth.uid()`

4. **Delete Permissions**:
   - ✅ **Only the creator** can delete their challenges
   - ✅ Enforced by: `created_by = auth.uid()`

5. **Join Permissions**:
   - ✅ Any user can join public challenges
   - ✅ Tracked in `challenge_participants` table

---

## 📋 Database Tables

### 1. **challenges** (Main table)
- Stores challenge details
- Tracks creator via `created_by`
- RLS enforces ownership rules

### 2. **challenge_participants** (Join tracking)
- Links users to challenges they've joined
- Tracks individual progress
- Anyone can join, only self can leave

### 3. **challenge_daily_contributions** (Progress tracking)
- Daily distance contributions per user
- Used for leaderboards
- Users can only update their own contributions

---

## 🔧 Setup Instructions

### Step 1: Run SQL Script

1. **Open Supabase Dashboard** → Your Project
2. **Go to**: SQL Editor
3. **Open**: `/Users/juan_oclock/Documents/ios-mobile/Taqvo/docs/supabase-challenges-setup.sql`
4. **Copy all SQL** and paste into Supabase
5. **Click**: Run

This will:
- ✅ Create `challenges` table (if not exists)
- ✅ Create `challenge_participants` table
- ✅ Create `challenge_daily_contributions` table
- ✅ Set up all RLS policies
- ✅ Create indexes for performance
- ✅ Add updated_at trigger

### Step 2: Verify Setup

Run this query in SQL Editor:
```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('challenges', 'challenge_participants', 'challenge_daily_contributions');

-- Check RLS policies
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('challenges', 'challenge_participants', 'challenge_daily_contributions')
ORDER BY tablename, policyname;
```

---

## 🧪 Testing

### Test 1: Create Challenge

1. Open Taqvo app
2. Go to Community tab
3. Tap "+" button
4. Fill in challenge details
5. Tap "Create"

**Expected**:
- Challenge appears in list
- `created_by` = your user ID
- `created_by_username` = your username

### Test 2: Delete Own Challenge

1. Find a challenge you created
2. Tap on it to view details
3. Tap "Delete" button
4. Confirm deletion

**Expected**:
- Challenge is deleted
- Removed from list

### Test 3: Try to Delete Someone Else's Challenge

1. Find a challenge created by another user
2. Tap on it to view details
3. Delete button should **not appear** (client-side check)

**Expected**:
- No delete button shown
- If somehow attempted, server returns 403 error

### Test 4: Join Challenge

1. Find any public challenge
2. Tap "Join Challenge"

**Expected**:
- You're added to `challenge_participants`
- Progress tracking begins
- Button changes to "Leave Challenge"

---

## 🎯 User Flows

### **Creator Flow**

```
User → Create Challenge
  ↓
Challenge saved with created_by = user.id
  ↓
Creator can:
  ✅ View challenge
  ✅ Edit challenge details
  ✅ Delete challenge
  ✅ View participants
  ✅ Join their own challenge
```

### **Participant Flow**

```
User → View Public Challenges
  ↓
User → Join Challenge
  ↓
Added to challenge_participants
  ↓
User can:
  ✅ View challenge
  ✅ Track progress
  ✅ Leave challenge
  ❌ Edit challenge details
  ❌ Delete challenge
```

---

## 📊 App Implementation Details

### **Create Challenge**

**Location**: `SupabaseCommunityDataSource.swift` lines 93-149

```swift
func createChallenge(...) async throws -> Challenge {
    // Automatically sets created_by to current user
    let userIdString = await authManager.userId
    
    // POST to /rest/v1/challenges
    // Body includes:
    // - created_by: userIdString
    // - created_by_username: current username
}
```

### **Delete Challenge**

**Location**: `SupabaseCommunityDataSource.swift` lines 151-167

```swift
func deleteChallenge(challengeID: UUID) async throws {
    // DELETE /rest/v1/challenges?id=eq.{challengeID}
    // RLS policy ensures only creator can delete
}
```

**Location**: `CommunityViewModel.swift` lines 329-339

```swift
func deleteChallenge(challengeID: UUID) async throws {
    // Client-side check: canDeleteChallenge()
    guard canDeleteChallenge(challenge) else {
        throw NSError(code: 403, "No permission")
    }
    
    // Server-side: RLS enforces ownership
    try await dataSource.deleteChallenge(challengeID: challengeID)
}
```

### **UI Permission Checks**

**Location**: `ChallengeDetailView.swift`

```swift
// Delete button only shown to creator
if community.canDeleteChallenge(currentChallenge) {
    Button("Delete Challenge", role: .destructive) {
        // Show confirmation alert
    }
}
```

---

## 🔒 Security Features

1. **Double Protection**:
   - ✅ Client-side checks (UI/UX)
   - ✅ Server-side RLS policies (security)

2. **Automatic Ownership**:
   - ✅ `created_by` set automatically from `auth.uid()`
   - ✅ Cannot be spoofed or manipulated

3. **Cascade Deletion**:
   - ✅ Deleting challenge removes all participants
   - ✅ Deleting challenge removes all contributions
   - ✅ Deleting user removes their challenges

4. **Public/Private Control**:
   - ✅ Creators can make challenges public or private
   - ✅ Private challenges only visible to creator
   - ✅ Public challenges visible to everyone

---

## 📝 Summary

| Feature | Status | Location |
|---------|--------|----------|
| **Challenge Ownership Tracking** | ✅ Implemented | `Challenge.createdBy` |
| **Creator Username Display** | ✅ Implemented | `Challenge.createdByUsername` |
| **Client-Side Permission Checks** | ✅ Implemented | `CommunityViewModel` |
| **Server-Side RLS Policies** | ⚠️ **Needs Setup** | Run SQL script |
| **Delete Functionality** | ✅ Implemented | `SupabaseCommunityDataSource` |
| **UI Permission Controls** | ✅ Implemented | `ChallengeDetailView` |
| **Join/Leave Functionality** | ✅ Implemented | `challenge_participants` |

**Action Required**: Run `supabase-challenges-setup.sql` to enable server-side security! 🚀

---

## 🆘 Troubleshooting

### Issue: Can't delete own challenge

**Check**:
1. RLS policies are set up correctly
2. User is authenticated
3. `created_by` matches `auth.uid()`

**Verify**:
```sql
SELECT id, title, created_by, auth.uid() as current_user
FROM challenges
WHERE id = '{challenge-id}';
```

### Issue: Can see delete button on others' challenges

**Check**:
1. `canDeleteChallenge()` logic in `CommunityViewModel`
2. `createdBy` field is properly populated
3. Current user ID is correctly retrieved

### Issue: 403 error when creating challenge

**Check**:
1. RLS INSERT policy exists
2. User is authenticated
3. `created_by` field matches `auth.uid()`

---

## 🎉 Conclusion

The challenge ownership system is **fully implemented** in the app code. You just need to:

1. ✅ Run `supabase-challenges-setup.sql` to create tables and RLS policies
2. ✅ Test creating, joining, and deleting challenges
3. ✅ Verify only creators can modify/delete their challenges

**Everything is ready to go!** 🚀
