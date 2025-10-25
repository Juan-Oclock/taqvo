# WeatherKit Setup Instructions

## Issue
The app is getting a sandbox restriction error when trying to access WeatherKit:
```
Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.weatherkit.authservice was invalidated: failed at lookup with error 159 - Sandbox restriction."
```

## Root Cause
WeatherKit requires proper entitlements and capabilities to be configured in Xcode. The app needs:
1. WeatherKit capability enabled
2. Proper entitlements file
3. Valid Apple Developer account with WeatherKit enabled

## Solution Steps

### 1. Enable WeatherKit Capability in Xcode

1. Open the project in Xcode
2. Select the **Taqvo** target
3. Go to **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **WeatherKit**
6. Make sure your Apple Developer account is selected under **Team**

### 2. Verify Entitlements File

The app should have a `Taqvo.entitlements` file with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.weatherkit</key>
    <true/>
</dict>
</plist>
```

### 3. Apple Developer Account Requirements

**Important:** WeatherKit requires:
- A valid Apple Developer Program membership ($99/year)
- WeatherKit must be enabled for your App ID in the Apple Developer Portal
- The app must be signed with a valid provisioning profile

### 4. Test on Real Device

**Note:** WeatherKit has limitations in the Simulator:
- May not work properly in iOS Simulator
- Best tested on a real iOS device
- Requires internet connection

### 5. Alternative: Mock Weather Data for Development

If you don't have WeatherKit access yet, we can add a fallback to mock weather data:

```swift
// In WeatherViewModel.swift
func fetchWeather(for location: CLLocation) async {
    #if targetEnvironment(simulator)
    // Use mock data in simulator
    self.cityName = "Davao City"
    self.errorMessage = nil
    // Create mock weather data
    return
    #endif
    
    // Real WeatherKit code...
}
```

## Quick Fix for Development

For immediate development without WeatherKit setup, you can:

1. **Option A:** Comment out the weather display temporarily
2. **Option B:** Add mock weather data for simulator/testing
3. **Option C:** Make weather optional (hide if unavailable)

## Verification Steps

After setup:
1. Clean build folder (Cmd + Shift + K)
2. Rebuild the app
3. Run on a real device (not simulator)
4. Check console for weather logs
5. Weather should display: "City • Condition Temperature°"

## Expected Behavior After Fix

✅ Location fetched successfully (already working)
✅ Weather data fetched from WeatherKit
✅ City name resolved via reverse geocoding
✅ Weather displays: "Davao City • Sunny 28°"

## Current Status

**Working:**
- ✅ Location permission granted
- ✅ Location coordinates fetched (7.023, 125.095 - Davao City area)
- ✅ Location manager functioning correctly

**Not Working:**
- ❌ WeatherKit authentication (sandbox restriction)
- ❌ Weather data fetch
- ❌ Weather display

## Additional Notes

### Other Issues Found in Logs

1. **ActivityKind "jog" error:**
   - Old activity data has "jog" which is no longer valid
   - Need to migrate old data or handle legacy values

2. **Challenge foreign key errors:**
   - Some challenge IDs don't exist in database
   - Clean up old challenge participant records

These are separate issues from WeatherKit and can be addressed separately.
