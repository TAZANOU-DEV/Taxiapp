# Taxi App Setup Guide

## ✅ What's Implemented

### 1. **Map & Real-Time Taxi Tracking** 🗺️
- Google Maps integration with real-time taxi position updates
- Color-coded markers:
  - 🔵 Blue = Your location
  - 🔴 Red = Nearby taxis / Requested
  - 🟢 Green = Taxis on the way
  - 🟠 Orange = Taxis arrived
- Location updates every 5 seconds
- Automatic taxi registration

### 2. **Settings & Profile Page** ⚙️
- **Edit Profile**: Update name, email, phone number
- **Change Password**: Secure password update with validation
- **Theme Switching**: Dark/Light mode toggle
- **Privacy & Security**: Manage location sharing, notifications, data collection
- **Logout**: Sign out functionality
- All changes apply immediately with success feedback

### 3. **Real-Time Socket.io Features**
- Incoming order notifications
- Order status tracking (on_way, arrived)
- Taxi registration and offline notifications
- Emergency alerts broadcast

---

## 🔧 Setting Up Google Maps API Key

### Step 1: Get API Key from Google Cloud
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
4. Create an API Key (Credentials → Create Credentials → API Key)

### Step 2: Add API Key to Android
Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in:
**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

### Step 3: Add API Key to iOS
Edit `ios/Runner/GeneratedPluginRegistrant.m` and add your key, or use:
**File**: `ios/Runner/Info.plist`

Add:
```xml
<key>com.google.ios.maps</key>
<string>YOUR_ACTUAL_API_KEY_HERE</string>
```

---

## 🚀 Running the App

### Android
```bash
flutter pub get
flutter run -d android
```

### iOS
```bash
cd ios
pod install
cd ..
flutter pub get
flutter run -d ios
```

---

## 📋 Features Checklist

### Map Features ✅
- [x] Real-time map display
- [x] Taxi location tracking
- [x] 5-second location refresh
- [x] Color-coded markers
- [x] Location error handling with retry

### Settings Features ✅
- [x] Profile editing (name, email, phone)
- [x] Password change with validation
- [x] Theme toggle (Dark/Light)
- [x] Privacy & Security controls
- [x] Logout functionality
- [x] Success notifications

### Socket.io Events ✅
- [x] taxi_location_updated
- [x] incoming_order
- [x] order_status_updated
- [x] taxi_offline
- [x] emergency alert
- [x] location updates

---

## 🔌 Backend Endpoints

### Location & Taxis
- `GET /api/taxi/nearby?lat=X&lng=Y` - Get nearby taxis
- `POST /api/taxi/location` - Update taxi location
- `POST /api/taxi/emergency` - Send emergency alert

### Orders
- `POST /api/taxi/order` - Create order
- `GET /api/taxi/orders/:taxiId` - Get active orders
- `PUT /api/taxi/order/:orderId` - Update order status

### Activities
- `GET /api/taxi/activities/:taxiId` - Get activity history

---

## 🐛 Troubleshooting

### Map Not Appearing
**Problem**: Error message instead of map
**Solutions**:
1. Check Google Maps API key is added correctly
2. Ensure location permissions are granted
3. Check internet connection
4. Run: `flutter clean && flutter pub get`

### Settings Not Saving
**Problem**: Changes don't persist after app restart
**Solution**: Currently saves in memory. To persist, implement:
- SharedPreferences for local storage
- Firebase Firestore for cloud sync
- SQLite database

### Location Not Updating
**Problem**: Taxi location stuck at old position
**Solutions**:
1. Check location permissions: Settings > Permissions > Location
2. Ensure GPS is enabled
3. Check internet for Socket.io connection
4. Verify location sharing toggle is ON

---

## 📱 Permissions Required

### Android (Already Added)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location for taxi tracking</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Your location is used for safety and order tracking</string>
```

---

## 📞 Support Features

- **Emergency Alert (SOS)**: Click red SOS button to broadcast emergency
- **Location Sharing**: Toggle switch to enable/disable location broadcast
- **Activity History**: View all recent actions in app
- **Nearby Taxis**: See list of connected taxis
- **Real-Time Map**: Watch taxis coming in real-time

---

## 🎨 Customization

### Change Theme Colors
Edit in files:
- Primary color: `Colors.yellow`
- Secondary color: `Colors.black`
- Success: `Colors.green`
- Error: `Colors.red`

### Change Map Zoom Level
In `home_page.dart`, change:
```dart
zoom: 15,  // Change this value (1-21)
```

### Change Location Update Interval
In `_startLocationSharing()`:
```dart
Duration(seconds: 5),  // Currently 5 seconds, adjust as needed
```

---

## ✨ Next Steps

1. **Add Database Persistence**
   - Save profile settings to database
   - Store activity history
   - Save chat messages

2. **Add Payment Integration**
   - Stripe/PayPal for orders
   - Ride pricing

3. **Add Rating System**
   - Rate drivers after rides
   - View driver ratings

4. **Add Message History**
   - Permanently store chat messages
   - Message search

---

For more help, check the code comments in:
- `lib/home_page.dart` - Main app
- `lib/settings_page.dart` - Settings
- `lib/service/socket_service.dart` - Real-time events
- `Backend/server.js` - Socket.io configuration
