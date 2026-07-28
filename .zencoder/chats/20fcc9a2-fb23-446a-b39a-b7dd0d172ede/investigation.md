# Investigation Report: Map Click Google Maps Redirection Bug

## Bug Summary
When clicking the map/markers or requesting directions on the map, the application does not correctly redirect the user to the person in danger sharing their location using Google Maps. This issue occurs due to a combination of:
1. **User Experience Confusions**: The in-app map renders OpenStreetMap (OSM) via the `flutter_map` package, not Google Maps. Clicking on the map itself has no action. The user must click the red warning marker to open `.\lib\emergency_navigation_page.dart`, and then click the **Start navigation** button.
2. **Missing Package Visibility Configurations (Android)**: Under Android 11 (API level 30) and newer, package visibility restrictions prevent the `url_launcher` package from querying or launching external schemes (like `google.navigation`, `https`, or `tel`) unless they are explicitly declared in the `<queries>` block of `.\android\app\src\main\AndroidManifest.xml`.
3. **Missing Custom Scheme Registrations (iOS)**: On iOS 9 and higher, custom URI schemes must be declared under the `LSApplicationQueriesSchemes` key in `.\ios\Runner\Info.plist`. Since this is missing, iOS blocks launching `comgooglemaps` or `https` links to open the external Google Maps app.
4. **Incorrect/Opaque URI Scheme Formatting**: 
   - On Android, the Google Maps Intent URL expects `google.navigation:q=latitude,longitude&mode=d`. The current codebase constructs this using the `Uri` class with query parameters and no host/path, generating `google.navigation:?q=...` (containing an erroneous `?`), which is rejected by the OS / Google Maps app.
   - On iOS, the `google.navigation` scheme is completely unsupported and returns `false`, causing fallback to a web link that often opens in Safari instead of the native Google Maps app.

---

## Root Cause Analysis

### 1. In-App Map Package Choice
The application uses the OpenStreetMap-based `flutter_map` package in both `.\lib\home_page.dart` and `.\lib\emergency_navigation_page.dart` to display maps. The map itself is not interactive with respect to Google Maps redirection. Tapping the warning icon marker is the only mechanism that routes to `.\lib\emergency_navigation_page.dart`.

### 2. Missing Android Package Visibility Queries
In `.\android\app\src\main\AndroidManifest.xml`, the `<queries>` tag only has:
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
</queries>
```
Without declaring standard view intents for `google.navigation`, `https`, and `tel` (for calling the requester), Android 11+ block `launchUrl()` from performing queries or successfully invoking target apps.

### 3. Missing iOS Application Queries Schemes
In `.\ios\Runner\Info.plist`, the `LSApplicationQueriesSchemes` array is missing entirely. iOS blocks querying or launching standard external applications like Google Maps or even web URLs via `launchUrl()` unless they are listed in `LSApplicationQueriesSchemes`.

### 4. Malformed Android URI & Lack of Native iOS Google Maps Support
In `_openGoogleMaps()` in `.\lib\emergency_navigation_page.dart`:
```dart
    final navigationUri = Uri(
      scheme: 'google.navigation',
      queryParameters: {'q': destination, 'mode': 'd'},
    );
```
- On Android, this generates `google.navigation:?q=...` instead of `google.navigation:q=...`.
- On iOS, `google.navigation` scheme is unrecognized, and the code relies entirely on falling back to `https://www.google.com/maps/dir/`. This fallback web URL often opens in Safari/browser instead of the native Google Maps app.

---

## Affected Components
- **`.\android\app\src\main\AndroidManifest.xml`**: Missing package visibility declarations for `https`, `google.navigation`, and `tel` schemes under the `<queries>` element.
- **`.\ios\Runner\Info.plist`**: Missing `LSApplicationQueriesSchemes` declarations for `comgooglemaps`, `google.navigation`, `https`, and `tel` schemes.
- **`.\lib\emergency_navigation_page.dart`**: Malformed URI scheme structure for `google.navigation` on Android, and missing native `comgooglemaps` launch URL handling on iOS.

---

## Proposed Solution

### 1. Update `.\android\app\src\main\AndroidManifest.xml`
Extend the `<queries>` block with standard intent definitions for web viewing, Google Maps navigation, and telephone calls:
```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="google.navigation" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
    </queries>
```

### 2. Update `.\ios\Runner\Info.plist`
Add the standard `LSApplicationQueriesSchemes` array to permit querying and launching external navigation, maps, calling, and browser packages:
```xml
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>google.navigation</string>
		<string>comgooglemaps</string>
		<string>comgooglemapsurl</string>
		<string>https</string>
		<string>tel</string>
	</array>
```

### 3. Refactor Google Maps Redirection in `.\lib\emergency_navigation_page.dart`
Modify `_openGoogleMaps()` to:
- Construct the correct opaque URI scheme `google.navigation:q=$destination&mode=d` for Android.
- Attempt native iOS Google Maps launch `comgooglemaps://?daddr=$destination&directionsmode=driving` when running on iOS.
- Fall back gracefully to `https://www.google.com/maps/dir/` web URL if the native scheme fails or maps application is not installed.

```dart
  Future<void> _openGoogleMaps() async {
    final origin =
        '${widget.responderLocation.latitude},${widget.responderLocation.longitude}';
    final destination =
        '${widget.emergencyLocation.latitude},${widget.emergencyLocation.longitude}';

    // 1. Standard Android navigation intent
    final androidUri = Uri.parse('google.navigation:q=$destination&mode=d');

    // 2. Standard iOS Google Maps native app intent
    final iosUri = Uri.parse('comgooglemaps://?saddr=$origin&daddr=$destination&directionsmode=driving');

    // 3. Graceful fallback web URL
    final directionsUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'origin': origin,
        'destination': destination,
        'travelmode': 'driving',
      },
    );

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final started = await launchUrl(
          androidUri,
          mode: LaunchMode.externalApplication,
        );
        if (started) return;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final started = await launchUrl(
          iosUri,
          mode: LaunchMode.externalApplication,
        );
        if (started) return;
      }
    } catch (e) {
      debugPrint('Native navigation launch failed: $e');
    }

    // Fallback to web directions (opens in maps or web browser)
    final opened = await launchUrl(
      directionsUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the navigation app.')),
      );
    }
  }
```
