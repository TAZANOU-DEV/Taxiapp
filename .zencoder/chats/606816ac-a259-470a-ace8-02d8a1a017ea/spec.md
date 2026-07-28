# Technical Specification: Emergency marker click does not launch Google Maps navigation

## Problem Statement

When the user taps the emergency warning marker on the map in `HomePage`,
the app opens `EmergencyNavigationPage` correctly, but tapping the
"Start navigation" button does **not** launch Google Maps to navigate to
the person in danger. In some cases tapping the marker itself may appear
to do nothing.

## Root Cause Analysis

Two independent failure points were identified:

### 1. Primary: Android Manifest `<queries>` is incomplete (Android 11+ package visibility)

**File:** `android/app/src/main/AndroidManifest.xml` (lines 46-51)

The current `<queries>` block only declares an intent for
`android.intent.action.PROCESS_TEXT` with mime type `text/plain`. This has
nothing to do with launching Google Maps or a phone dialer.

On **Android 11 (API 30) and above**, apps cannot resolve intents to other
installed apps unless they are explicitly declared in the `<queries>`
section of the manifest (or the `QUERY_ALL_PACKAGES` permission is granted,
which is restricted on the Play Store).

The `_openGoogleMaps` method in `emergency_navigation_page.dart` (line 146)
calls `launchUrl` with:
- A `google.navigation:` custom-scheme URI (line 151-154)
- A fallback `https://www.google.com/maps/dir/...` URL (line 155-164)

Neither of these can resolve to an app because the manifest does not
declare queries for the `google.navigation` or `https` schemes. As a
result, `launchUrl` returns `false` on both attempts, and the user sees
the SnackBar: *"Unable to open the navigation app."*

The same problem affects `_callRequester` (line 183) which uses a `tel:`
URI — no query is declared for the `tel` scheme either.

### 2. Secondary: iOS `Info.plist` missing `LSApplicationQueriesSchemes`

**File:** `ios/Runner/Info.plist`

iOS requires `LSApplicationQueriesSchemes` to be declared for any custom
URL scheme the app wants to launch via `canOpenURL` / `launchURL`. The
plist is missing this key entirely. While `url_launcher` with
`LaunchMode.externalApplication` may still work without it, declaring the
schemes is required for reliable behavior and App Store compliance.

### 3. Tertiary: `currentPosition == null` guard blocks marker tap

**File:** `lib/home_page.dart` (line 1052)

`_openEmergencyNavigation` guards with:
```dart
if (emergencyLocation == null || currentPosition == null) { ... return; }
```

If the device's GPS location has not yet been acquired (`currentPosition`
is `null`), tapping the emergency marker shows a SnackBar *"Current and
emergency locations are required."* instead of opening the navigation
page. The user perceives this as "clicking the map does nothing useful."

### 4. Quaternary: `google.navigation` URI format includes a `?`

**File:** `lib/emergency_navigation_page.dart` (line 151-154)

`Uri(scheme: 'google.navigation', queryParameters: {...})` produces
`google.navigation:?q=lat,lng&mode=d`. The canonical Google Maps
navigation intent format is `google.navigation:q=lat,lng&mode=d` (no `?`).
While the `?` is a valid URI delimiter and Google Maps typically handles
it, using `Uri.parse` with the exact format is safer and more predictable.

---

## Difficulty Assessment

**Medium** — The core fix is platform configuration (Android manifest,
iOS plist) which is straightforward but has Android 11+ package-visibility
edge cases. A secondary UX improvement in the Flutter code adds some
complexity around ensuring location is acquired before navigation.

---

## Technical Context

- **Language:** Dart (Flutter)
- **Platforms:** Android (primary target), iOS (secondary)
- **Key dependencies:**
  - `url_launcher: ^6.3.2` — launches external apps / URLs
  - `flutter_map: ^8.3.0` — in-app map rendering
  - `geolocator: ^14.0.3` — device GPS location
  - `latlong2: ^0.9.1` — LatLng coordinate type
- **Backend:** Vercel-hosted Express API (`https://taxiapp-back.vercel.app`)
- **Relevant files:**
  - `.\lib\home_page.dart` — map, markers, `_openEmergencyNavigation`
  - `.\lib\emergency_navigation_page.dart` — navigation page, `_openGoogleMaps`, `_callRequester`
  - `.\android\app\src\main\AndroidManifest.xml` — Android manifest
  - `.\ios\Runner\Info.plist` — iOS configuration

---

## Implementation Approach

### Change 1: Add required `<queries>` to AndroidManifest.xml

Add intent filters so `url_launcher` can resolve and launch:
- `google.navigation` scheme → Google Maps app turn-by-turn navigation
- `https` scheme → Google Maps web fallback (and any browser)
- `geo` scheme → generic geo intents (maps apps)
- `tel` scheme → phone dialer (for the "Call" button)

Replace the existing `<queries>` block with:
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="google.navigation" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="geo" />
    </intent>
    <intent>
        <action android:name="android.intent.action.DIAL" />
        <data android:scheme="tel" />
    </intent>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT" />
        <data android:mimeType="text/plain" />
    </intent>
</queries>
```

### Change 2: Add `LSApplicationQueriesSchemes` to iOS Info.plist

Add the following key so iOS allows launching Google Maps and the dialer:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlemaps</string>
    <string>google.navigation</string>
    <string>comgooglemaps</string>
    <string>tel</string>
    <string>maps</string>
</array>
```

### Change 3: Ensure location is acquired before opening navigation (home_page.dart)

In `_openEmergencyNavigation`, instead of silently returning when
`currentPosition == null`, attempt to acquire the location first. If it
still fails, show a clear SnackBar. This ensures the marker tap always
attempts to open the navigation page when an emergency location exists.

### Change 4: Fix the `google.navigation` URI format (emergency_navigation_page.dart)

Replace the `Uri(scheme: ...)` construction with an explicit string using
`Uri.parse` to avoid the injected `?`:
```dart
final navigationUri = Uri.parse(
  'google.navigation:q=$destination&mode=d',
);
```

---

## Source Code Structure Changes

| File | Change |
|------|--------|
| `.\android\app\src\main\AndroidManifest.xml` | Expand `<queries>` with `google.navigation`, `https`, `geo`, `tel` intent filters |
| `.\ios\Runner\Info.plist` | Add `LSApplicationQueriesSchemes` array |
| `.\lib\home_page.dart` | Make `_openEmergencyNavigation` acquire location if `currentPosition` is null |
| `.\lib\emergency_navigation_page.dart` | Fix `google.navigation` URI to use `Uri.parse` without `?` |

---

## Data Model / API / Interface Changes

None. No backend, data model, or widget API signatures change.

---

## Verification Approach

1. **Lint / typecheck:** Run `flutter analyze` from the project root to confirm no static analysis errors in the modified Dart files.
2. **Build (Android):** Run `flutter build apk --debug` to verify the manifest changes compile correctly.
3. **Manual verification (Android device/emulator with Google Maps installed):**
   - Trigger an emergency alert from a second device/account.
   - On the responder device, confirm the emergency warning marker appears on the map.
   - Tap the warning marker → `EmergencyNavigationPage` should open.
   - Tap "Start navigation" → Google Maps should launch in turn-by-turn navigation mode toward the emergency coordinates.
   - Tap "Call" (if phone number available) → phone dialer should open with the number pre-filled.
4. **Fallback verification:** If Google Maps app is not installed, the `https://www.google.com/maps/dir/...` URL should open in the browser.
5. **Error case:** If device location cannot be acquired, tapping the marker should show a clear SnackBar explaining the issue.

---

## Notes / Open Questions

- The Android `<queries>` changes require a **full app rebuild** (not hot reload) to take effect, since manifest changes are processed at build time.
- The `google.navigation` scheme only works if the **Google Maps app** is installed. The `https` fallback handles the case where it is not.
- No changes are needed to the backend or the emergency alert delivery mechanism — the issue is purely client-side (platform configuration + URI format).
