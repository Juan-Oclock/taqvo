# Supabase Community Data Source Implementation

## ✅ Implementation Complete

The Supabase HTTP functions have been fully implemented to replace the previous stubs.

---

## 🔧 What Was Implemented

### **1. HTTP Helper Functions**

#### **GET Request** (`get<T: Decodable>`)
- Builds URL with query parameters
- Adds Supabase headers (`apikey`, `Authorization`)
- Handles authentication tokens
- Decodes JSON response
- Error handling with detailed logging

#### **POST Request** (`post<T: Decodable>`)
- Sends JSON body
- Adds `Prefer: return=representation` header
- Handles both array and single object responses
- Handles empty responses (for inserts)
- Error handling with detailed logging

#### **DELETE Request** (`delete`)
- Builds URL with query parameters
- Adds Supabase headers
- Handles authentication tokens
- Error handling with detailed logging

---

## 📡 API Endpoints Used

### **Challenges**

**Load Challenges:**
```
GET /rest/v1/challenges?select=...&is_public=eq.true&order=start_date.asc
```

**Create Challenge:**
```
POST /rest/v1/challenges
Body: {
  id, title, detail, start_date, end_date,
  goal_distance_meters, is_public, created_by, created_by_username
}
```

**Delete Challenge:**
```
DELETE /rest/v1/challenges?id=eq.{challengeID}
```

### **Challenge Participants**

**Join Challenge:**
```
POST /rest/v1/challenge_participants
Body: { challenge_id, user_id }
```

**Leave Challenge:**
```
DELETE /rest/v1/challenge_participants?challenge_id=eq.{id}&user_id=eq.{id}
```

---

## 🔑 Required Headers

All requests include:
- `Content-Type: application/json`
- `Accept: application/json`
- `apikey: {SUPABASE_ANON_KEY}` (from Info.plist)
- `Authorization: Bearer {access_token}` (when user is authenticated)

POST requests also include:
- `Prefer: return=representation` (to get created data back)

---

## 🗄️ Database Schema Required

### **challenges table**
```sql
CREATE TABLE challenges (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  detail TEXT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  goal_distance_meters DOUBLE PRECISION,
  is_public BOOLEAN DEFAULT true,
  created_by UUID REFERENCES auth.users(id),
  created_by_username TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### **challenge_participants table**
```sql
CREATE TABLE challenge_participants (
  challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (challenge_id, user_id)
);
```

---

## 🔒 RLS Policies Needed

### **challenges table**

**SELECT (Read):**
```sql
-- Allow reading public challenges
CREATE POLICY "Public challenges are viewable by everyone"
ON challenges FOR SELECT
USING (is_public = true);

-- Allow reading own challenges
CREATE POLICY "Users can view their own challenges"
ON challenges FOR SELECT
USING (auth.uid() = created_by);
```

**INSERT (Create):**
```sql
-- Allow authenticated users to create challenges
CREATE POLICY "Authenticated users can create challenges"
ON challenges FOR INSERT
WITH CHECK (auth.uid() = created_by);
```

**DELETE:**
```sql
-- Only creator can delete
CREATE POLICY "Users can delete their own challenges"
ON challenges FOR DELETE
USING (auth.uid() = created_by);
```

### **challenge_participants table**

**SELECT (Read):**
```sql
-- Allow reading participants of public challenges
CREATE POLICY "Public challenge participants are viewable"
ON challenge_participants FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM challenges
    WHERE challenges.id = challenge_participants.challenge_id
    AND challenges.is_public = true
  )
);
```

**INSERT (Join):**
```sql
-- Allow users to join challenges
CREATE POLICY "Users can join challenges"
ON challenge_participants FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

**DELETE (Leave):**
```sql
-- Allow users to leave challenges they joined
CREATE POLICY "Users can leave challenges"
ON challenge_participants FOR DELETE
USING (auth.uid() = user_id);
```

---

## 🐛 Bug Fixes Included

### **1. Date Format Consistency**
- **Issue**: `createChallenge` was using `ISO8601DateFormatter` but `loadChallenges` expected `yyyy-MM-dd`
- **Fix**: Changed to use consistent `yyyy-MM-dd` format

### **2. User-Specific Join States**
- **Issue**: Join states were stored in shared UserDefaults keys
- **Fix**: Keys now include user ID: `community_join_states_{userId}`

### **3. Auth State Reload**
- **Issue**: Challenges persisted in memory when users switched accounts
- **Fix**: Clear and reload challenges when auth state changes

### **4. Always Reload on View Appear**
- **Issue**: Community view only loaded if challenges were empty
- **Fix**: Always reload when view appears

---

## 📊 Debug Logging

All HTTP functions include debug logging:

**Success:**
```
DEBUG: createChallenge() - Successfully created challenge on server: {UUID}
DEBUG: setJoinState() - User joined challenge: {UUID}
DEBUG: loadChallenges() - Fetched X rows from server
```

**Errors:**
```
DEBUG: Supabase GET error (403): {"message":"..."}
DEBUG: Supabase POST error (400): {"message":"..."}
DEBUG: createChallenge() - Error creating challenge: ...
```

---

## 🧪 Testing Checklist

### **User A (Creator)**
- [x] Create public challenge
- [x] Challenge auto-joins (saved to local state)
- [x] Challenge saved to database
- [x] Log out

### **User B (Viewer)**
- [x] Log in
- [x] View challenges (loaded from database)
- [x] Challenge shows "Join Challenge" button
- [x] Join challenge
- [x] Join state saved to database
- [x] Button changes to "Leave Challenge"

### **User A (Returns)**
- [x] Log back in
- [x] Still sees challenge as joined
- [x] Can delete own challenge

---

## 🚀 What Works Now

✅ **Challenges are saved to Supabase database**  
✅ **Challenges are loaded from Supabase database**  
✅ **Users can join/leave challenges**  
✅ **Join states are user-specific**  
✅ **Challenges persist across sessions**  
✅ **Challenges are shared between users**  
✅ **RLS policies enforce permissions**  
✅ **Auth tokens are included in requests**  
✅ **Error handling with detailed logs**

---

## 📝 Configuration Required

### **Info.plist**
```xml
<key>SUPABASE_URL</key>
<string>https://your-project.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>your-anon-key-here</string>
```

### **Supabase Dashboard**
1. Create `challenges` table
2. Create `challenge_participants` table
3. Enable RLS on both tables
4. Add the policies listed above
5. Ensure auth is configured

---

## 🎉 Summary

The Supabase integration is now **fully functional**! Challenges are:
- ✅ Created and stored in the database
- ✅ Loaded from the database for all users
- ✅ Properly isolated per user (join states)
- ✅ Shared between users (public challenges)
- ✅ Protected by RLS policies

**The auto-join bug is completely fixed!** 🚀
