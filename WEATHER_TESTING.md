# Testing Weather Feature

## For Android Emulator

### Method 1: Set Location in Emulator
1. Start your Android emulator
2. Click the **⋮ (three dots)** button on the right side
3. Select **"Location"**
4. In the location panel:
   - Search for a city (e.g., "Kuala Lumpur")
   - OR enter coordinates manually:
     - Latitude: `3.1390` (KL)
     - Longitude: `101.6869` (KL)
5. Click **"SEND"** to set the location
6. Restart the app and click "Retry"

### Method 2: Enable GPS in Settings
1. In the emulator, swipe down from top
2. Long-press the **Location** icon
3. Make sure it's turned ON
4. Restart your app

### Method 3: Using ADB Command
```bash
adb emu geo fix 101.6869 3.1390
```

## For Real Device

1. Go to **Settings** → **Location** (or **Privacy** → **Location Services** on some devices)
2. Turn ON location services
3. Open the app
4. When prompted, grant location permission
5. Click "Retry" if needed

## For iOS Simulator

```bash
# Set location using simulator
xcrun simctl location <device-id> set 3.1390 101.6869
```

## Troubleshooting

### "Unable to load weather" Error
**Possible causes:**
- Location services are disabled
- App doesn't have location permission
- No internet connection
- GPS signal unavailable

**Solutions:**
1. Click the **"Settings"** button in the app → Enable location
2. Click **"Retry"** after enabling location
3. Check your internet connection
4. Try the ADB command for emulator

### API Not Responding
- Check internet connection
- Verify API key is valid (should be working)
- API might have rate limits (60 calls/minute for free tier)

## Expected Behavior

When working correctly, you should see:
- Current temperature and weather conditions
- Weather icon matching the conditions
- Humidity, wind speed, UV index, etc.
- 3-day forecast
- Agricultural recommendations

## Quick Test

Run this in your terminal while emulator is running:
```bash
# Set location to Kuala Lumpur
adb emu geo fix 101.6869 3.1390

# Then hot reload your app
# Press 'r' in the terminal where flutter run is active
```
