# Supabase Setup Guide for Taqvo Profile Features

## 🚨 Issue: Profile Data Not Saving

**Error**: `new row violates row-level security policy for table "profiles"`

**Root Cause**: The `profiles` table has Row Level Security (RLS) enabled but missing INSERT policy.

---

## ✅ Solution: Set Up RLS Policies

### Step 1: Fix Profiles Table RLS Policies

1. **Go to Supabase Dashboard** → Your Project
2. **Navigate to**: SQL Editor (left sidebar)
3. **Create New Query**
4. **Copy and paste** the contents of `supabase-profiles-rls-setup.sql`
5. **Click "Run"**

This will:
- ✅ Allow users to INSERT their own profile (fixes the 403 error)
- ✅ Allow users to UPDATE their own profile
- ✅ Allow users to SELECT (view) their own profile
- ✅ Optionally allow public viewing (for leaderboards)

### Step 2: Set Up Storage Bucket for Profile Photos

1. **In Supabase Dashboard** → SQL Editor
2. **Create New Query**
3. **Copy and paste** the contents of `supabase-storage-setup.sql`
4. **Click "Run"**

This will:
- ✅ Create the `avatars` storage bucket
- ✅ Set up storage policies for user uploads
- ✅ Make avatars publicly readable

---

## 🧪 Testing After Setup

### Test 1: Save Username Only

1. Open Taqvo app
2. Go to Profile tab
3. Enter username: "Mr Juan"
4. **Don't upload a photo**
5. Tap "Save Changes"

**Expected Console Output**:
```
DEBUG: Starting profile update - UserID: 5c762515-b680-4323-95ef-dcae69a676b0
DEBUG: Username: Mr Juan, Has Image: false
DEBUG: Updating profile in database...
DEBUG: Profile upsert response status: 201  ← Should be 201 or 200
✅ SUCCESS: Profile saved to database
```

6. Sign out and sign in again
7. Go to Profile tab
8. **Username should persist!** ✅

### Test 2: Save Username + Photo

1. Open Taqvo app
2. Go to Profile tab
3. Enter username: "Mr Juan"
4. **Upload a profile photo**
5. Tap "Save Changes"

**Expected Console Output**:
```
DEBUG: Starting profile update - UserID: 5c762515-b680-4323-95ef-dcae69a676b0
DEBUG: Username: Mr Juan, Has Image: true
DEBUG: Uploading profile image...
DEBUG: Image uploaded successfully - URL: https://...
DEBUG: Updating profile in database...
DEBUG: Profile upsert response status: 201
✅ SUCCESS: Profile saved to database
```

6. Sign out and sign in again
7. Go to Profile tab
8. **Both username and photo should persist!** ✅

---

## 📋 Profiles Table Schema

Your `profiles` table should have these columns:

```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

If the table doesn't exist, create it with:

```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
```

Then run the RLS policies from `supabase-profiles-rls-setup.sql`.

---

## 🔍 Troubleshooting

### Issue: Still getting 403 error

**Check**:
1. RLS policies are created correctly
2. User is authenticated (check `auth.uid()` in SQL editor)
3. The `id` column in profiles table is UUID type
4. The `id` matches the user's auth.uid()

**Verify in SQL Editor**:
```sql
-- Check current user
SELECT auth.uid();

-- Check policies
SELECT * FROM pg_policies WHERE tablename = 'profiles';

-- Try manual insert (should work if policies are correct)
INSERT INTO profiles (id, username) 
VALUES (auth.uid(), 'Test User')
ON CONFLICT (id) DO UPDATE SET username = 'Test User';
```

### Issue: Photo upload fails with "Bucket not found"

**Solution**: Run `supabase-storage-setup.sql` to create the `avatars` bucket.

### Issue: Photo uploads but can't be viewed

**Check**:
1. Bucket is set to `public = true`
2. Storage policies allow SELECT for public
3. Avatar URL is correctly formatted

---

## 📝 Summary

| Component | Status | Action Required |
|-----------|--------|----------------|
| **Profiles Table** | ✅ Exists | Run RLS setup SQL |
| **RLS Policies** | ❌ Missing INSERT | **CRITICAL - Run SQL now** |
| **Storage Bucket** | ❌ Not created | Run storage setup SQL |
| **App Code** | ✅ Fixed | Already handles errors gracefully |

**Priority**: Run `supabase-profiles-rls-setup.sql` first to fix the 403 error!

---

## 🎯 Expected Behavior After Setup

- ✅ Username saves to database
- ✅ Username persists after logout/login
- ✅ Profile photo uploads to Supabase Storage
- ✅ Photo URL saves to database
- ✅ Photo persists after logout/login
- ✅ Email displays in profile (already working)
- ✅ Changes sync across devices

---

## 📞 Need Help?

If you still encounter issues after running the SQL scripts:

1. Check Supabase Dashboard → Logs for detailed errors
2. Verify your user is authenticated: `SELECT auth.uid();`
3. Check the console output for specific error messages
4. Ensure your Supabase project URL and anon key are correct in Info.plist
