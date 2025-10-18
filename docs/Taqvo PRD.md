# 🏃‍♂️ Taqvo — Product Requirements Document (PRD)

**Version:** 1.0  
**Date:** October 2025  
**Prepared by:** Taqvo Product Team  
**Design Framework:** SwiftUI + Framer Motion (animation references)  
**Platform:** iOS (iPhone, Apple Watch - future phase)

---

## 🎯 1. Product Overview

**Taqvo** is a minimalist running and walking companion app designed to track every step and stride with precision.  
Unlike other fitness apps cluttered with excessive data and distractions, **Taqvo** focuses on *motion, community, and progress.*  
It combines real-time activity tracking with social engagement and insights to make movement rewarding and effortless.

---

## 🌍 2. Mission Statement

> “Every step counts. Every stride matters. Move smarter with Taqvo.”

Taqvo empowers everyday walkers and runners to track their motion effortlessly while connecting with like-minded individuals in a clean, motivating environment.

---

## 🧭 3. Target Audience

- Urban runners and walkers who prefer minimal, distraction-free interfaces.  
- Users transitioning from fitness trackers like Strava, Nike Run Club, and Adidas Running.  
- Health-conscious individuals who want simple, accurate motion tracking integrated with Apple Health and Spotify/Apple Music.

---

## 🧩 4. Core App Navigation

**Bottom Navigation (5 tabs):**

| Tab | Description |
|------|--------------|
| **Feed** | Discover your runs, friends’ activities, and highlights. |
| **Community** | Challenges, groups, and leaderboards. |
| **Activity (Center)** | Main button to start running or walking. |
| **Insights** | Personal analytics and progress trends. |
| **Profile** | User settings, integrations, and preferences. |

---

## ⚙️ 5. Feature Breakdown & Flow

### **A. Feed**
- Scrollable feed of personal and community activities.
- Post-run highlights: distance, time, route snapshot, calories.
- Social interactions: like, comment, share.
- Tapping an activity opens a detailed stats view (map, pace, splits).

---

### **B. Community**
- Join and view challenges.
- Create or join local clubs.
- See leaderboards filtered by distance, pace, or streaks.
- Join challenge CTA connects to Activity screen for tracking.

---

### **C. Activity (Central CTA)**
#### **Pre-Run Setup**
- Select type: Walk / Jog / Run  
- Choose goal: Time / Distance / None  
- Music integration:
  - Connect **Spotify** or **Apple Music** accounts.
  - Option to play music or curated playlists within the run.
- Permissions:
  - Location access (for route tracking)
  - Motion access (for steps, cadence)
  - HealthKit (for optional sync)

#### **During Activity**
- **Live Metrics:** Time, Distance, Pace (primary); swipe up for cadence, elevation.
- **Map View:** optional expandable map view.
- **Controls:**
  - Pause / Resume
  - End activity
  - Add marker (photo, note)
- **Haptics:** Vibration on milestones (1km, 5km, etc.)
- **Background Mode:** continues tracking if user locks screen or switches apps.

#### **Post-Run Summary**
- Summary card: map, distance, time, pace.
- Insights preview: total calories, pace trends.
- Add photo/note and share to Feed.
- Option to export or sync to Apple Health.

---

### **D. Insights**
- Daily, weekly, and monthly progress cards.
- Charts for total distance, average pace, and active days.
- Trends visualization (using Swift Charts or custom view).
- Streak and milestone tracking.
- Compare progress with past weeks.
- Export or share summary.

---

### **E. Profile**
- Profile picture, bio, and total stats.
- Integrations:
  - Connect / Disconnect Spotify
  - Connect / Disconnect Apple Music
  - Apple Health sync
- Privacy Settings:
  - Activity visibility (Public, Friends, Private)
  - Share toggles
- Account:
  - Notifications, language, dark mode, support, logout

---

## 🔒 6. Permissions & Privacy

- **Location Services:** Required for route tracking.  
- **Motion & Fitness:** Required for steps and cadence data.  
- **Apple Health:** Optional integration (user-controlled).  
- **Music Access:** Spotify or Apple Music authentication via OAuth.  
- **Data Privacy:** All user data is locally cached and securely synced using HTTPS with encryption at rest.  

---

## 🎨 7. Visual Design System

### **Color Palette**

| Role | Hex | Description |
|------|-----|--------------|
| **Primary Dark Background** | `#4F4F4F` | App-wide dark theme base |
| **Primary Text (Dark Mode)** | `#F6F8FA` | Main text color on dark background |
| **Primary Text (Light Mode)** | `#111111` | Main text color on white background |
| **Accent Text** | `#C5C5C5` | Secondary or muted text |
| **CTA / Highlight** | `#A8FF60` | Key action, active states, progress |

### **Typography**
- **Primary Font:** Helvetica Neue  
- **Weights:** Regular / Medium / Bold  
- **Font Sizes:**  
  - Title: 24pt  
  - Subtitle: 18pt  
  - Body: 14pt  
  - Caption: 12pt  

### **Visual Identity**
- Minimalist aesthetic — dark UI with bright lime CTA.  
- Rounded UI elements (corner radius 16pt).  
- Subtle shadows and soft gradients for depth.  

---

## 🎞️ 8. Animation Framework

### **Framer Motion (for concept prototypes)**
Used in **Framer** or **React prototypes** for animation design testing:
- Transitions for screen reveals.
- Activity button breathing effect.
- Smooth bottom tab transitions.

### **SwiftUI Animations (production app)**
- `.spring()` for run-start button interactions.
- `.easeInOut` transitions for modals.
- Implicit animations on progress rings and charts.
- Lottie for activity completion checkmarks or map highlights.

---

## 📊 9. Data Architecture Overview

| Data Type | Source | Notes |
|------------|---------|-------|
| GPS Route | Core Location | Tracks location and path |
| Steps / Cadence | Core Motion | Continuous background sampling |
| Health Data | HealthKit | Optional sync (user-controlled) |
| Music Data | Spotify/Apple Music SDK | Playback and metadata access |
| User Profiles | Cloud | Social & analytics data |
| Activities | Local → Cloud Sync | GPX files + metrics |
| Feed / Community | Cloud | Managed by Firebase or Supabase |

---

## 🧠 10. App Flow Overview

Splash → Onboarding → Permissions → Feed → Community → Activity (Run) → Post-run Summary → Insights → Profile
	•	From Feed: Tap a run → Detailed stats.
	•	From Community: Join challenge → auto-populates Activity type.
	•	From Profile: Manage integrations and privacy.
	•	From Activity: Tap “End” → Summary → Option to share or save.
	

## 🧠 11. MVP Scope
Included:
	•	Core run tracking (GPS, steps, pace)
	•	Feed (social + activity sharing)
	•	Community challenges
	•	Insights (weekly stats)
	•	Profile & integrations
	•	Spotify/Apple Music connection
	•	SwiftUI interface with smooth animations
	
	12. Monetization (Future Consideration)
	•	Free tier: Full tracking, community access, insights.
	•	Premium (future): Advanced analytics, custom challenges, music playlist integrations.
	
	13. Development Resources

iOS Development
	•	Apple Developer Documentation
	•	SwiftUI Tutorials by Apple
	•	Human Interface Guidelines (HIG)
	•	Core Motion Framework
	•	Core Location Framework
	•	Spotify iOS SDK
	•	MusicKit (Apple Music API)

Design & Animation
	•	Framer Motion Documentation
	•	LottieFiles for SwiftUI
	•	Swift Charts Guide
	•	SF Symbols
	
	
14. Technical Stack (Suggested)

UI - SwiftUI + Combine
Animation -  SwiftUI Animations / Lottie
Data Sync -Firebase
Health & Motion - Core Motion + HealthKit
Mapping - MapKit
Music Integration - Spotify SDK / MusicKit
Design Prototyping - Figma 

15. Success Metrics (KPIs)
	•	% of users completing first run after install (activation)
	•	Weekly active users (WAU)
	•	Avg. runs per week per user
	•	Feed engagement (likes/comments per post)
	•	Spotify/Apple Music connection rate
	•	Retention after 30 days
	
	🚀 16. Future Vision
	•	Live events and challenges with brands.
	•	AI-generated insights and weekly summaries.
	•	Apple Watch standalone mode.
	•	Taqvo Web Dashboard for coaches and teams.
	
	🧾 17. Summary

Taqvo will stand out by offering:
	•	Minimal design
	•	Smooth SwiftUI interactions
	•	Smart motion tracking
	•	Social connectivity
	•	Music-powered motivation

Prepared by:
Taqvo Product & Design Team
2025 © All rights reserved.