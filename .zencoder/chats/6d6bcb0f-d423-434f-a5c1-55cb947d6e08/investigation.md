# SOS Feature Improvements - Investigation Findings

## Summary
The current SOS feature broadcasts alerts, but it's missing some key details (phone number and profile picture) in the mobile UI. The backend already fetches most of this information but the frontend doesn't fully utilize it. Navigation to the emergency location via Google Maps is already implemented but can be improved with better profile visibility.

## Root Cause Analysis
- **Missing Fields**: `phone` and `pictureUrl` are not consistently passed through the `SocketService` to the UI overlays.
- **Frontend Data Loading**: `HomePage` doesn't load the user's phone number or cached profile picture URL from `SharedPreferences` to include them in the emergency payload.
- **UI Limitations**: The emergency alert card and overlay in the Flutter app do not have a field to display the responder's/requester's phone number.

## Affected Components
- `.\lib\home_page.dart`: `sendEmergency` payload and `_emergencyAlertCard` UI.
- `.\lib\service\socket_service.dart`: `onEmergencyAlert` listener and `sendEmergency` method.
- `.\lib\notification.dart`: `showEmergencyOverlay` method and UI.
- `.\backend\routes\auth.js`: `GET /profile` endpoint (needs to return `phone` and `profile_image`).

## Proposed Solution
1. **Backend Update**:
   - Update `GET /api/auth/profile` in `.\backend\routes\auth.js` to return `phone` and `profile_image`.
2. **Frontend Service Update**:
   - Update `SocketService.onEmergencyAlert` to handle the `phone` field.
   - Update `SocketService.sendEmergency` to include `phone`, `taxiMatricule`, and `pictureUrl`.
3. **Notification Update**:
   - Update `NotificationService.showEmergencyOverlay` to accept and display a `phone` row.
4. **HomePage Update**:
   - Load `user_phone` and `profile_image_url` in `_loadSavedUserProfile`.
   - Update `sendEmergency` to include all profile details.
   - Add a `phone` display row to `_emergencyAlertCard`.
   - Ensure the "View emergency location" button transitions smoothly to the navigation page.
5. **Navigation**:
   - The existing `EmergencyNavigationPage` already supports opening Google Maps with a polyline. No major changes needed here other than potentially passing the phone number for a "Call" button.

**Shall I proceed with implementing these fixes?**

---

## Implementation Notes

All changes below have been implemented and verified with `flutter analyze` (no new errors introduced; only pre-existing warnings remain).

### 1. Backend (`.\backend\routes\auth.js`)
- **`GET /profile`**: Now selects `phone` and `profile_image` from the `users` table. The `profile_image` is converted to a full URL (prefixed with `BACKEND_URL`) if it's a relative path.
- **`POST /login`**: The login query now also selects `phone` and `profile_image`, and the response includes both fields so the client can cache them immediately on login.

### 2. SocketService (`.\lib\service\socket_service.dart`)
- **`sendEmergency`**: Added optional parameters `phone`, `taxiMatricule`, and `pictureUrl`. These are included in the emitted `emergency` payload when provided.
- **`emergencyAlert` listener**: Now passes `data['phone']` to `NotificationService.showEmergencyOverlay`.

### 3. NotificationService (`.\lib\notification.dart`)
- **`showEmergencyOverlay`**: Added a `phone` parameter. The overlay dialog now displays a "Phone: ..." row between the email and matricule rows when a phone number is available.

### 4. HomePage (`.\lib\home_page.dart`)
- Added state variables `userPhone` and `userProfileImageUrl`.
- **`_loadSavedUserProfile`**: Now reads `user_phone` and `profile_image_url` from `SharedPreferences` and calls the new `_fetchUserProfile` method.
- **`_fetchUserProfile`** (new): Fetches the latest profile from `GET /api/auth/profile` and updates `userPhone`/`userProfileImageUrl` (also persists to `SharedPreferences`).
- **`sendEmergency`** (HTTP): The request body now includes `phone` and `pictureUrl`.
- **`sendEmergencyAlert`**: Now passes `phone`, `taxiMatricule`, and `pictureUrl` to `socketService.sendEmergency`.
- **`onEmergencyAlert` listener**: `emergencyDetails` now includes the `phone` field.
- **`_pollEmergencyAlerts`**: The polling fallback now maps `alert['taxi_phone']` to the `phone` field.
- **`_emergencyAlertCard`**: Added a "Phone: ..." display row between the email and matricule rows.
- **`_openEmergencyNavigation`**: Now passes `requesterPhone` to `EmergencyNavigationPage`.

### 5. EmergencyNavigationPage (`.\lib\emergency_navigation_page.dart`)
- Added a `requesterPhone` parameter.
- Added a `_callRequester` method that opens the `tel:` URI to call the requester.
- The bottom panel now displays the requester's phone number and a "Call" button (when a phone is available) alongside the "Start navigation" button.

### 6. LoginPage (`.\lib\login_page.dart`)
- On successful login, now saves `user_phone` and `profile_image_url` to `SharedPreferences` (when provided by the backend).

