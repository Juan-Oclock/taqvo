# Taqvo (iOS)

Taqvo is an iOS app for tracking runs and workouts, showing live activity stats and routes, and controlling music playback while you move. It supports both Spotify and Apple Music with a user-selectable provider toggle and an option to auto-stop playback when your activity ends or a goal is reached.

## Features
- Activity tracking with distance, pace, time, and route.
- Live Activity view with map route and real-time stats.
- Music integration:
  - Provider toggle (Spotify or Apple Music) persisted across sessions.
  - Contextual controls gated by selected provider and authorization.
  - Optional auto-stop music when activity ends or goal is reached.
- Preview page to test provider toggle and UI behavior.
- Unit and UI test targets.

## Requirements
- Xcode 15 or later.
- iOS 16+ simulator or device (device builds require valid provisioning). 
- Spotify account and app credentials (if you plan to use Spotify).
- Apple Music subscription (for Apple Music controls).

## Getting Started
1. Clone the repo:
   ```bash
   git clone git@github.com:Juan-Oclock/taqvo.git
   cd taqvo
   ```
2. Open the project in Xcode:
   ```
   open Taqvo.xcodeproj
   ```
3. Run on the iOS Simulator using Xcode or via CLI:
   ```bash
   xcodebuild -scheme Taqvo -sdk iphonesimulator -configuration Debug build
   ```

## Building and Running
- Simulator: select `Taqvo` scheme and a simulator device in Xcode, then run.
- Physical device: ensure your Apple developer team, bundle ID, and provisioning profiles are set up. If you see a provisioning error, switch to the simulator or update signing settings.

## Music Integrations
- Provider selection is stored with `@AppStorage("preferredMusicProvider")` and is respected across the app.
- Spotify-specific state may store the last device with `@AppStorage("spotifyLastDeviceID")`.
- Controls appear only for the chosen provider and if authorized.
- When `autoStopMusicOnEnd` is enabled, playback will stop based on the selected provider.

Relevant files:
- `Taqvo/LiveActivityView.swift` — Provider-gated controls and stop-on-end logic.
- `Taqvo/SpotifyViewModel.swift` — Spotify playback and device handling.
- `Taqvo/MusicViewModel.swift` — Apple Music integration and playback control.
- `Taqvo/MainTabView.swift` — App navigation and goal management.

## Preview Page (Provider Toggle)
A lightweight HTML preview exists to try out the provider toggle UI without running the full app:

- File: `preview-spotify-integration.html`
- Start a local server:
  ```bash
  # If 8000 is available
  python3 -m http.server 8000
  # If ports are busy, use ephemeral port 0 and check the printed URL
  python3 -m http.server 0
  ```
- Open in your browser:
  - `http://localhost:8000/preview-spotify-integration.html`
  - Or the ephemeral port URL printed in the terminal.

## Tests
Run unit tests on the simulator:
```bash
xcodebuild -scheme TaqvoTests -sdk iphonesimulator test
```
Run UI tests:
```bash
xcodebuild -scheme TaqvoUITests -sdk iphonesimulator test
```

## Project Structure (trimmed)
```
Taqvo/
├── ActivityDetailView.swift
├── ActivityTrackingViewModel.swift
├── LiveActivityView.swift
├── MainTabView.swift
├── MusicViewModel.swift
├── SpotifyAuthManager.swift
├── SpotifyViewModel.swift
└── TaqvoApp.swift
```

## Notes
- You may see deprecation warnings for `onChange(of:)` on iOS 17; functionality is unaffected.
- Device builds require valid signing and provisioning. Use the simulator to skip signing issues.

## License
TBD