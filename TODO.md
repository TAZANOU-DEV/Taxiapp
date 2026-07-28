# Implementation Plan - Emergency Safety Enhancement

## Steps:
- [x] 1. Analyze codebase and create plan  
- [x] 2. Confirm plan with user  
- [ ] 3. **`lib/home_page.dart`** — Add `_stopLocationSharing()` in `stopEmergencyAlert()` so location stops broadcasting when emergency is cleared  
- [ ] 4. **`lib/home_page.dart`** — Fix pictureUrl check in `_emergencyAlertCard()` to handle empty string  
- [ ] 5. **`lib/home_page.dart`** — Add SnackBar notification for receiving taxis when emergency is cleared  
- [ ] 6. **`lib/notification.dart`** — Ensure `showEmergencyOverlay()` properly shows taxiMatricule  
- [ ] 7. **`lib/socket_service.dart`** — Ensure `sendEmergencyCleared` includes detailed message for notification  
- [ ] 8. Verify all changes compile correctly
