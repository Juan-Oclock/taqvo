# Taqvo Configuration Guide

## Required API Keys and Configuration

Before running the app, you need to configure the following API keys and credentials:

### 1. Supabase Configuration

Edit `Taqvo/Info.plist` and replace the placeholders:

```xml
<key>SUPABASE_URL</key>
<string>YOUR_SUPABASE_URL</string>
<key>SUPABASE_ANON_KEY</key>
<string>YOUR_SUPABASE_ANON_KEY</string>
```

Get your Supabase credentials from:
- Go to https://supabase.com/dashboard
- Select your project
- Go to Settings > API
- Copy the Project URL and anon/public key

### 2. Spotify Configuration

Edit `Taqvo/SpotifyAuthManager.swift` and replace:

```swift
private let clientID: String = "YOUR_SPOTIFY_CLIENT_ID"
```

Get your Spotify Client ID:
- Go to https://developer.spotify.com/dashboard
- Create or select your app
- Copy the Client ID
- Add `taqvo://spotify-callback` to your Redirect URIs

### 3. Apple Music

Apple Music integration uses MusicKit which requires:
- Apple Developer account
- MusicKit capability enabled in Xcode
- No additional configuration needed

## Security Notes

⚠️ **IMPORTANT**: Never commit actual API keys to version control!

- Keep your keys in `Info.plist` (which should be in `.gitignore`)
- Use environment variables for CI/CD
- Rotate keys if accidentally exposed

## Setup Checklist

- [ ] Configure Supabase URL and Key
- [ ] Configure Spotify Client ID
- [ ] Enable required capabilities in Xcode
- [ ] Test authentication flows
- [ ] Verify permissions are working

## Support

For issues with configuration, check:
- Supabase: https://supabase.com/docs
- Spotify: https://developer.spotify.com/documentation
