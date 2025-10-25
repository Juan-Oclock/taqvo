# Goal Wiring Update - Implementation Summary

## Overview
Wired the goal details from the onboarding "Getting to Know You" page to the "Ready to Move" activity setup screen. Replaced the goal selection UI with a compact goal display card that shows the user's selected goal with an edit option.

## Changes Made

### 1. New State Variables in MainTabView

**Added:**
```swift
@State private var frequencyPerWeek: Int = 3
@State private var showGoalEditSheet: Bool = false
```

- `frequencyPerWeek`: Tracks how many times per week the user wants to do the activity
- `showGoalEditSheet`: Controls the presentation of the goal edit sheet

### 2. Load Goal Preferences from Onboarding

**Updated `onAppear` to load saved preferences:**
```swift
// Load frequency from onboarding preferences
if let savedFrequency = UserDefaults.standard.object(forKey: "defaultFrequencyPerWeek") as? Int {
    frequencyPerWeek = savedFrequency
}

// Load goal from onboarding if not set
if let savedGoalType = UserDefaults.standard.string(forKey: "defaultGoalType") {
    if let goalType = Goal(rawValue: savedGoalType) {
        goal = goalType
    }
}
if let savedDistance = UserDefaults.standard.object(forKey: "defaultDistanceGoalMeters") as? Double {
    distanceKilometers = savedDistance / 1000.0
}
if let savedTime = UserDefaults.standard.object(forKey: "defaultTimeGoalSeconds") as? Double {
    timeMinutes = Int(savedTime / 60.0)
}
```

**UserDefaults Keys Used:**
- `defaultFrequencyPerWeek` - Frequency (1-7 days)
- `defaultGoalType` - Goal type (none/distance/time)
- `defaultDistanceGoalMeters` - Distance in meters
- `defaultTimeGoalSeconds` - Time in seconds

### 3. Replaced Goal Selection with Goal Display Card

**Before:**
- Goal selection cards (Free Run, Distance Goal, Time Goal)
- Expandable sliders for distance/time
- No frequency display

**After:**
- Compact goal display card
- Shows current goal with icon
- Displays frequency and target (e.g., "3x/week, 5.0km each")
- Edit button (pencil icon) to modify goal

### 4. Goal Display Card Component

**Visual Design:**
- Icon with lime CTA background (40x40px circle)
- Goal title (16pt semibold)
- Goal description with frequency (13pt regular)
- Edit button (pencil.circle.fill icon, 28pt)
- Card background (black 20% opacity)
- 16pt corner radius

**Dynamic Content:**
- **Free Run:** "No specific goal - track freely"
- **Distance Goal:** "3x/week, 5.0km each"
- **Time Goal:** "3x/week, 30min each"

### 5. Goal Edit Sheet

**Full-Screen Sheet with:**
1. **Goal Type Selection**
   - Free Run, Distance Goal, Time Goal cards
   - Checkmark on selected type
   - Lime CTA styling for selected state

2. **Goal Details (Distance/Time)**
   - Slider for distance (1-42.2 km) or time (10-180 min)
   - Large value display (28pt bold)
   - Min/max labels

3. **Frequency Selector**
   - 7 circular buttons (1-7 days)
   - Only shown for Distance and Time goals
   - Lime CTA for selected day

4. **Navigation Bar**
   - Title: "Edit Goal"
   - Cancel button (left)
   - Done button (right, saves changes)

### 6. Save Goal Changes Function

**Saves to both UserDefaults and AppStorage:**
```swift
private func saveGoalChanges() {
    // Save to UserDefaults (for consistency with onboarding)
    UserDefaults.standard.set(goal.rawValue, forKey: "defaultGoalType")
    UserDefaults.standard.set(frequencyPerWeek, forKey: "defaultFrequencyPerWeek")
    
    if goal == .distance {
        UserDefaults.standard.set(distanceKilometers * 1000, forKey: "defaultDistanceGoalMeters")
    } else if goal == .time {
        UserDefaults.standard.set(Double(timeMinutes * 60), forKey: "defaultTimeGoalSeconds")
    }
    
    // Also save to AppStorage keys (for activity tracking)
    storedGoalType = goal.rawValue
    storedGoalDistanceMeters = distanceKilometers * 1000
    storedGoalTimeSeconds = Double(timeMinutes * 60)
}
```

## User Flow

### Initial Setup (From Onboarding)
1. User completes "Getting to Know You" onboarding
2. Selects activity type, goal type, distance/time, and frequency
3. Goal preferences saved to UserDefaults
4. User completes onboarding

### Activity Setup Screen
1. User opens "Ready to Move" screen
2. Goal card displays saved preferences from onboarding
3. Shows: "Distance Goal - 3x/week, 5.0km each"
4. User can tap edit button to modify

### Edit Goal Flow
1. Tap pencil icon on goal card
2. Sheet opens with current goal settings
3. User can change goal type, distance/time, frequency
4. Tap "Done" to save changes
5. Goal card updates with new settings
6. Changes persist for future sessions

## Design System Applied

### Goal Display Card
- **Icon:** 24pt, lime CTA color, 40x40px circle background
- **Title:** 16pt semibold
- **Description:** 13pt regular, gray text
- **Edit Button:** 28pt pencil icon, lime CTA
- **Card:** 16px padding, 16pt corner radius

### Goal Edit Sheet
- **Background:** Dark gray (#4F4F4F)
- **Cards:** Black 20% opacity, 12-16pt corners
- **Selected State:** Lime CTA color, 10% opacity background
- **Frequency Buttons:** 40x40px circles
- **Sliders:** Lime CTA tint
- **Text:** White and white 70% opacity

## Key Features

✅ Seamless data flow from onboarding to activity setup
✅ Compact goal display replaces selection UI
✅ Frequency display integrated into goal description
✅ Easy editing via sheet modal
✅ Consistent design with onboarding
✅ Saves to both UserDefaults and AppStorage
✅ Maintains existing activity tracking functionality

## Before vs After

### Before
```
Ready to Move?

Activity Type: [Walk] [Run] [Trail Run] [Hiking]

Goal:
[ ] Free Run
[ ] Distance Goal
[ ] Time Goal

[Distance Slider if selected]

[Start Activity Button]
```

### After
```
Ready to Move?

Activity Type: [Walk] [Run] [Trail Run] [Hiking]

Your Goal:
[📍 Distance Goal                    ✏️]
[   3x/week, 5.0km each              ]

[Start Activity Button]
```

## Files Modified
- ✅ MainTabView.swift

## Testing Recommendations
1. Complete onboarding with different goal types
2. Verify goal displays correctly on activity setup
3. Test edit button opens sheet
4. Verify goal changes save correctly
5. Test frequency selector (1-7 days)
6. Verify Free Run shows no frequency
7. Test distance and time sliders
8. Verify changes persist across app restarts
9. Test activity tracking uses correct goal values
