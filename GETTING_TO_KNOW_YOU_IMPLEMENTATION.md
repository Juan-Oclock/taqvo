# Getting to Know You - Implementation Summary

## Overview
A new onboarding page has been added between the permissions page and the main app to collect user information and set default activity goals.

## Files Created/Modified

### New File: `GettingToKnowYouView.swift`
A complete SwiftUI view with two-step onboarding flow.

#### Step 1: Personal Information
- **Name** - Text field (required)
- **Birthdate** - Date picker (defaults to 25 years ago)
- **Location** - Text field for city/country

#### Step 2: Activity Goals
- **Preferred Activity Type** - 2x2 grid with cards:
  - Walk (blue)
  - Jog (orange)
  - Run (red)
  - Ride (purple)
  
- **Default Goal Type** - Three options:
  - Free Run (no goal)
  - Distance Goal (1-42.2 km)
  - Time Goal (10-180 minutes)
  
- **Goal Details** - Sliders appear based on selection:
  - Distance slider with km display
  - Time slider with minute display

### Modified File: `OnboardingView.swift`
- Added `GettingToKnowYouView()` as page 2 (tag: 2) in the TabView
- Updated permissions page buttons to navigate to page 2 instead of completing onboarding
- The flow is now: Login → Permissions → Getting to Know You → Main App

## Data Storage
User preferences are saved to `UserDefaults`:
- `userName` - String
- `userBirthdate` - Date
- `userLocation` - String
- `preferredActivityType` - String (walk/jog/run/ride)
- `defaultGoalType` - String (none/time/distance)
- `defaultDistanceGoalMeters` - Double (converted from km)
- `defaultTimeGoalSeconds` - Double (converted from minutes)

## Design System Applied
- **Background**: #4F4F4F (dark gray)
- **CTA Color**: Lime green (#A8FF60)
- **Card backgrounds**: black.opacity(0.2)
- **Corner radius**: 12-16pt on cards, 28pt on buttons
- **Fonts**: System fonts with proper weights
- **Animations**: Spring animations for interactions

## User Flow
1. User completes email/social login
2. User grants permissions (location, motion, background)
3. **NEW**: User fills in personal info (name required)
4. **NEW**: User sets activity preferences (optional)
5. User taps "Get Started" → enters main app

## Validation
- Step 1 requires non-empty name to proceed
- Step 2 has no validation (all optional)
- Users can skip the entire flow from step 1
- Users can go back from step 2 to step 1

## Components Created
- `ActivityTypeCard` - Colored cards for activity selection
- `GoalTypeCard` - Cards with icons for goal type selection
- Progress indicator showing current step (2 bars)
- Custom sliders for distance and time goals

## Next Steps (Optional Enhancements)
1. Sync user data to Supabase profiles table
2. Use stored preferences to pre-fill Activity setup screen
3. Add profile editing capability in ProfileView
4. Add location autocomplete/suggestions
5. Add age-based recommendations for goals
