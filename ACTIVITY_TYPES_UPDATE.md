# Activity Types Update - Implementation Summary

## Overview
Updated the app to use new activity types (walk, run, trail run, hiking) instead of the old types (walk, jog, run, ride). Also implemented accordion-style goal selection in the Getting to Know You page.

## Changes Made

### 1. Core Activity Types (AppState.swift)
Updated `ActivityIntentType` enum:
- ✅ **walk** - Blue, figure.walk icon
- ✅ **run** - Red, figure.run icon  
- ✅ **trailRun** - Orange, figure.hiking icon
- ✅ **hiking** - Green, figure.hiking icon

**Removed:** jog, ride

### 2. Getting to Know You Page (GettingToKnowYouView.swift)

#### Activity Type Cards
- Updated 2x2 grid to show: Walk, Run, Trail Run, Hiking
- Updated icons and colors to match new types
- Trail Run and Hiking both use figure.hiking icon

#### Accordion-Style Goal Selection
- **New Component:** `AccordionGoalCard<Content: View>`
- Goals expand/collapse with smooth spring animations
- Shows chevron down/up when expandable
- Shows checkmark when selected but not expanded
- Content (sliders) appears inside the expanded card

**Goal Types:**
1. **Free Run** - No expansion, just selection
2. **Distance Goal** - Expands to show distance slider (1-42.2 km)
3. **Time Goal** - Expands to show time slider (10-180 min)

### 3. Activity Tracking (ActivityTrackingViewModel.swift)

Updated speed thresholds for auto-pause/resume:
- **Walk:** 0.5/0.6 m/s (unchanged)
- **Run:** 1.4/2.0 m/s (unchanged)
- **Trail Run:** 1.0/1.5 m/s (new - slower than run)
- **Hiking:** 0.4/0.7 m/s (new - slower than walk)

Updated MET values for calorie estimation:
- **Walk:** 3.5 MET
- **Run:** 9.8 MET
- **Trail Run:** 7.5 MET (new)
- **Hiking:** 6.0 MET (new)

### 4. Main Tab View (MainTabView.swift)

Updated in multiple locations:
- Activity type selection grid
- Activity type to tracking kind mapping
- Intent handling for preselection
- Activity card icons
- Activity title generation ("Morning Walk", "Morning Trail Run", etc.)
- Verb generation ("Walked", "Trail Ran", "Hiked")

### 5. Post Run Summary (PostRunSummaryView.swift)

Updated:
- Verb display for share images
- HealthKit workout configuration:
  - Walk → .walking
  - Run, Trail Run → .running
  - Hiking → .hiking
- Removed cycling-specific distance type
- Updated workout import from HealthKit

### 6. Comments (CommentsBottomSheet.swift)

Updated activity name display:
- "Walking", "Running", "Trail Running", "Hiking"

## Design System

### Activity Type Colors
- **Walk:** Blue
- **Run:** Red
- **Trail Run:** Orange
- **Hiking:** Green

### Accordion Card Features
- Lime CTA border when selected
- 10% lime background tint when selected
- Smooth spring animations (0.3s response)
- Chevron indicators for expandable items
- Checkmark for selected non-expandable items
- Content padding: 16px inside expanded area

## User Experience Improvements

1. **Clearer Activity Types:** Removed ambiguous "jog" and "ride", focused on walking/running activities
2. **Trail Run Option:** Dedicated option for off-road running with appropriate thresholds
3. **Hiking Support:** Proper support for slower-paced hiking activities
4. **Accordion Goals:** Cleaner UI with expandable goal details, reduces visual clutter
5. **Consistent Icons:** Trail run and hiking both use figure.hiking for visual consistency

## Files Modified
1. ✅ AppState.swift
2. ✅ GettingToKnowYouView.swift
3. ✅ ActivityTrackingViewModel.swift
4. ✅ MainTabView.swift
5. ✅ PostRunSummaryView.swift
6. ✅ CommentsBottomSheet.swift

## Testing Recommendations
1. Test activity type selection in Getting to Know You page
2. Verify accordion expansion/collapse animations
3. Test activity creation with each new type
4. Verify auto-pause thresholds for trail run and hiking
5. Test HealthKit sync for all activity types
6. Verify activity display in feed with new types
7. Test activity import from HealthKit
