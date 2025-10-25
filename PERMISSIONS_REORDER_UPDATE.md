# Permissions Reorder Update - Implementation Summary

## Overview
Moved the permissions page after "Getting to Know You" onboarding and added notification, camera, and calendar permissions with a skip option. Users are reminded they can set permissions later in Settings.

## Changes Made

### 1. Reordered Onboarding Flow

**Previous Order:**
1. Main onboarding (sign in/sign up)
2. Permissions page
3. Getting to Know You

**New Order:**
1. Main onboarding (sign in/sign up)
2. Getting to Know You (personal info, activity goals)
3. Permissions page (now final step)

### 2. Added New Permissions

**New Permissions Added:**
- **Notifications** - Get reminders and activity updates
- **Camera** - Take photos during activities
- **Calendar** - Schedule and track workout plans

**Existing Permissions:**
- Location - Required for route tracking
- Motion & Fitness - Required for steps and cadence
- Background Tracking - Allows tracking if screen locks

### 3. Updated Permission Descriptions

**Added reminder text:**
```
"You can always set these later in Settings"
```

This appears below the main description to reassure users they can skip and configure later.

### 4. Updated Navigation Flow

**Getting to Know You:**
- "Get Started" button → Navigates to Permissions page (not completing onboarding)
- "Skip for now" button → Navigates to Permissions page

**Permissions Page:**
- "Get Started" button → Completes onboarding
- "Skip for now" button → Completes onboarding

### 5. PermissionsViewModel Updates

**Added Imports:**
```swift
import UserNotifications
import AVFoundation
import EventKit
```

**Added Published Properties:**
```swift
@Published var notificationAuthorized: Bool = false
@Published var cameraAuthorized: Bool = false
@Published var calendarAuthorized: Bool = false
```

**Added Methods:**

**Notifications:**
```swift
func requestNotificationAuthorization()
func checkNotificationAuthorization()
```

**Camera:**
```swift
func requestCameraAuthorization()
func checkCameraAuthorization()
```

**Calendar:**
```swift
func requestCalendarAuthorization()
func checkCalendarAuthorization()
```

### 6. Permission Status Checking

**On permissions page appear:**
- Checks all permission statuses
- Updates UI to show current authorization state
- Users can see which permissions are already granted

## User Flow

### Complete Flow
1. **Main Onboarding** → Sign in/Sign up
2. **Getting to Know You** → Enter personal info, select activity & goals
3. **Permissions** → Grant permissions or skip
4. **App Main Screen** → Start using the app

### Skip Options

**Step 2 (Getting to Know You):**
- "Skip for now" → Goes to Permissions page

**Step 3 (Permissions):**
- "Skip for now" → Completes onboarding, enters app
- Can configure permissions later in Settings

## Design System Applied

### Permission Cards
- Icon with title and description
- Enable button for each permission
- Visual feedback when granted
- Consistent with existing design

### Messaging
- Clear descriptions of what each permission does
- Reassurance that settings can be changed later
- Non-blocking flow with skip option

### Button Styling
- "Get Started" - Lime CTA button (primary action)
- "Skip for now" - Underlined text link (secondary action)

## Key Features

✅ Permissions moved after personal info collection
✅ Added notification, camera, calendar permissions
✅ "Set later" reminder for user reassurance
✅ Skip option on permissions page
✅ All permissions optional (can skip entire page)
✅ Permission status checked on page load
✅ Smooth navigation between steps
✅ Completes onboarding after permissions

## Permission Descriptions

### Notification
- **Icon:** bell.fill
- **Title:** Notifications
- **Description:** Get reminders and activity updates

### Camera
- **Icon:** camera.fill
- **Title:** Camera
- **Description:** Take photos during your activities

### Calendar
- **Icon:** calendar
- **Title:** Calendar
- **Description:** Schedule and track your workout plans

### Location (Existing)
- **Icon:** location.fill
- **Title:** Location
- **Description:** Required for route tracking

### Motion & Fitness (Existing)
- **Icon:** figure.walk
- **Title:** Motion & Fitness
- **Description:** Required for steps and cadence

### Background Tracking (Existing)
- **Icon:** location.circle.fill
- **Title:** Background Tracking
- **Description:** Allows tracking if screen locks or you switch apps

## Files Modified
- ✅ OnboardingView.swift - Reordered pages, added new permissions
- ✅ GettingToKnowYouView.swift - Updated to navigate to permissions
- ✅ PermissionsViewModel.swift - Added notification, camera, calendar support

## Testing Recommendations
1. Test complete flow: Sign in → Getting to Know You → Permissions → App
2. Test skip button on Getting to Know You page
3. Test skip button on Permissions page
4. Verify each permission request works correctly
5. Test that permissions can be granted individually
6. Verify "set later" message displays
7. Test that skipping permissions still completes onboarding
8. Verify permission status updates when granted
9. Test navigation back to Settings to configure permissions later
