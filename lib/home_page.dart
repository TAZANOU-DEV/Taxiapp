import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../service/socket_service.dart';
import 'about_page.dart';
import 'settings_page.dart';
import 'notification.dart';
import 'chat_page.dart';
import 'emergency_navigation_page.dart';
import 'notification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.userName, this.taxiId});

  final String? userName;
  final String? taxiId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String userName = 'John Doe';
  String taxId = 'Unknown';
  String userMatricule = '';
  String userEmail = '';
  String userPhone = '';
  String userProfileImageUrl = '';
  int? userId;
  bool isOnline = true;
  bool isInDanger = false;
  bool _isSOSHovered = false;

  Position? currentPosition;
  String? locationError;
  List<Map<String, dynamic>> nearbyTaxis = [];
  Timer? locationTimer;
  bool isSharingLocation = false;

  String? activeEmergencyRequesterId;
  String? activeEmergencyRequesterName;
  LatLng? emergencyLocation;
  Map<String, dynamic>? emergencyDetails;
  double? _emergencyDistance;
  double? _emergencyDuration;
  final Set<String> helpersOnWay = {};

// Track each helper's location (lat,lng) and route polyline
  final Map<String, LatLng> _helperLocations = {};
  final Map<String, List<LatLng>> _helperPolylines = {};
  // Track helper display names (matricules)
  final Map<String, String> _helperNames = {};
  final Map<String, Set<String>> helpersByRequest =
      {}; // track helpers per requesting taxi

  // Track nearby taxi matricules for display
  final Map<String, String> _nearbyTaxiMatricules = {};
  // Track polylines to nearby taxis (for location sharing route visualization)
  final Map<String, List<LatLng>> _nearbyTaxiPolylines = {};
  final bool _showLocationPolylines = false;

  // Polling fallback for emergency alerts (Vercel serverless doesn't support Socket.io WebSocket)
  final Set<int> _processedEmergencyAlertIds = {};
  Timer? _emergencyPollTimer;

  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  final double _defaultZoom = 15.0;
  final SocketService socketService = SocketService();

  List<Map<String, String>> activities = [
    {"title": "Emergency alert sent", "time": "Today - 10:45 AM"},
    {"title": "Location shared", "time": "Yesterday - 6:12 PM"},
  ];

  String get backendBaseUrl {
    return 'https://taxiapp-back.vercel.app';
  }

  Future<void> sendEmergency() async {
    try {
      if (currentPosition == null) {
        await _getCurrentLocation();
      }
      if (currentPosition == null) {
        const errorMessage =
            'Unable to send emergency because location is unavailable.';
        debugPrint(errorMessage);
        NotificationService.showNotification(
          title: 'Emergency Failed',
          body: errorMessage,
          type: 'emergency',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final displayLabel = userMatricule.isNotEmpty ? userMatricule : taxId;
      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/taxi/emergency'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'taxiId': taxId,
          'lat': currentPosition?.latitude,
          'lng': currentPosition?.longitude,
          'message': 'Emergency alert from taxi $displayLabel',
          'taxiNumber': taxId,
          'taxiMatricule': userMatricule,
          'driverName': userName,
          'email': userEmail,
          'phone': userPhone,
          'pictureUrl': userProfileImageUrl,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("Emergency sent successfully");
        NotificationService.showNotification(
          title: 'Emergency Alert Sent',
          body: 'Your emergency alert has been sent to nearby drivers',
          type: 'emergency',
        );
        setState(() {
          activities
              .insert(0, {"title": "Emergency alert sent", "time": "Just now"});
        });
      } else {
        final errorBody = response.body;
        debugPrint(
            "Failed to send emergency: ${response.statusCode} $errorBody");
        NotificationService.showNotification(
          title: 'Emergency Alert Failed',
          body:
              'Failed to send emergency alert (${response.statusCode}). Please try again.',
          type: 'emergency',
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      NotificationService.showNotification(
        title: 'Error',
        body: 'Error sending emergency alert: $e',
        type: 'emergency',
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        locationError = 'Location service is disabled. Enable it and refresh.';
      });
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          locationError =
              'Location permission denied. Grant permission and restart.';
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationError =
            'Location permission permanently denied. Enable in settings.';
      });
      return;
    }
    setState(() {
      locationError = null;
    });
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      currentPosition = position;
    });
  }

  Future<void> _shareLocation() async {
    if (currentPosition == null) return;
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/taxi/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taxiId': taxId,
          'lat': currentPosition!.latitude,
          'lng': currentPosition!.longitude,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint("Location shared successfully");
        NotificationService.showNotification(
          title: 'Location Shared',
          body: 'Your location has been shared with nearby drivers',
          type: 'update',
        );
        setState(() {
          activities
              .insert(0, {"title": "Location shared", "time": "Just now"});
        });
      }
    } catch (e) {
      debugPrint("Error sharing location: $e");
    }
  }

  Future<void> _fetchNearbyTaxis() async {
    if (currentPosition == null) return;
    try {
      final response = await http.get(
        Uri.parse(
            '$backendBaseUrl/api/taxi/nearby?lat=${currentPosition!.latitude}&lng=${currentPosition!.longitude}'),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          nearbyTaxis = data.map((t) => t as Map<String, dynamic>).toList();
          _buildMapMarkers();
        });
      }
    } catch (e) {
      debugPrint("Error fetching nearby taxis: $e");
    }
  }

  /// Polling fallback for emergency alerts.
  /// Since Vercel serverless functions don't support persistent Socket.io WebSocket
  /// connections, this method periodically fetches pending emergency alerts from
  /// the backend via HTTP and triggers the same handler as the socket listener.
  Future<void> _pollEmergencyAlerts() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$backendBaseUrl/api/emergency-alerts?status=pending&limit=50'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final alerts = data['alerts'] as List<dynamic>? ?? [];
          for (final alert in alerts) {
            final alertId = alert['alert_id'];
            if (alertId == null) continue;
            if (_processedEmergencyAlertIds.contains(alertId)) continue;

            final alertTaxiId = alert['taxi_id']?.toString();
            if (alertTaxiId == null || alertTaxiId == taxId) continue;

            _processedEmergencyAlertIds.add(alertId);

            // Trigger the same handler as the socket listener
            if (socketService.onEmergencyAlert != null) {
              socketService.onEmergencyAlert!(Map<String, dynamic>.from({
                'taxiId': alertTaxiId,
                'taxiNumber': alert['taxi_license_plate'] ?? alertTaxiId,
                'driverName': alert['taxi_driver_name'] ??
                    alert['full_name'] ??
                    'Unknown',
                'email': alert['email'] ?? '',
                'phone': alert['taxi_phone'] ?? '',
                'taxiMatricule': alert['taxi_matricule'] ?? '',
                'pictureUrl': '',
                'message': alert['message'] ?? '',
                'lat': alert['latitude'],
                'lng': alert['longitude'],
              }));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error polling emergency alerts: $e');
    }
  }

  // Decode encoded polyline (precision 5) from OSRM/Mapbox into List<LatLng>
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final latitude = lat / 1e5;
      final longitude = lng / 1e5;
      poly.add(LatLng(latitude, longitude));
    }

    return poly;
  }

  // Fetch route from OSRM public API and render as polyline
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=polyline');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['routes'] != null && body['routes'].isNotEmpty) {
          final route = body['routes'][0];
          final geometry = route['geometry'] as String;
          final points = _decodePolyline(geometry);
          setState(() {
            _emergencyDistance = (route['distance'] as num?)?.toDouble();
            _emergencyDuration = (route['duration'] as num?)?.toDouble();
            _polylines = [
              Polyline(
                points: points,
                strokeWidth: 6.0,
                color: Colors.blueAccent,
              ),
            ];
          });
          return;
        }
      }
      // Fallback to straight line if routing failed
      setState(() {
        _emergencyDistance = null;
        _emergencyDuration = null;
        _polylines = [
          Polyline(
            points: [from, to],
            strokeWidth: 4.0,
            color: Colors.redAccent.withOpacity(0.5),
          ),
        ];
      });
    } catch (e) {
      debugPrint('Failed to fetch route: $e');
      setState(() {
        _emergencyDistance = null;
        _emergencyDuration = null;
        _polylines = [
          Polyline(
            points: [from, to],
            strokeWidth: 4.0,
            color: Colors.redAccent.withOpacity(0.5),
          ),
        ];
      });
    }
  }

// Fetch route to a nearby taxi (for location sharing polyline visualization)
  Future<void> _fetchLocationRoute(
      String taxiKey, LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=polyline');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['routes'] != null && body['routes'].isNotEmpty) {
          final route = body['routes'][0];
          final geometry = route['geometry'] as String;
          final points = _decodePolyline(geometry);
          setState(() {
            _nearbyTaxiPolylines[taxiKey] = points;
          });
          _buildMapMarkers();
          return;
        }
      }
      // Fallback to straight line
      setState(() {
        _nearbyTaxiPolylines[taxiKey] = [from, to];
      });
      _buildMapMarkers();
    } catch (e) {
      debugPrint('Failed to fetch location route: $e');
      setState(() {
        _nearbyTaxiPolylines[taxiKey] = [from, to];
      });
      _buildMapMarkers();
    }
  }

  // Fetch route for a specific helper and store the polyline (for requester view)
  Future<void> _fetchHelperRoute(
      String helperKey, LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=polyline');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['routes'] != null && body['routes'].isNotEmpty) {
          final route = body['routes'][0];
          final geometry = route['geometry'] as String;
          final points = _decodePolyline(geometry);
          setState(() {
            _helperPolylines[helperKey] = points;
          });
          _buildMapMarkers();
          return;
        }
      }
      // Fallback to straight line
      setState(() {
        _helperPolylines[helperKey] = [from, to];
      });
      _buildMapMarkers();
    } catch (e) {
      debugPrint('Failed to fetch helper route: $e');
      setState(() {
        _helperPolylines[helperKey] = [from, to];
      });
      _buildMapMarkers();
    }
  }

  String _formatEmergencyDistance() {
    if (_emergencyDistance == null) return '';
    if (_emergencyDistance! < 1000) return '${_emergencyDistance!.round()} m';
    return '${(_emergencyDistance! / 1000).toStringAsFixed(1)} km';
  }

  String _formatEmergencyDuration() {
    if (_emergencyDuration == null) return '';
    final minutes = (_emergencyDuration! / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  void _startLocationSharing() {
    _getCurrentLocation().then((_) {
      if (currentPosition != null) {
        // Broadcast initial location
        socketService.broadcastLocationUpdate(
          taxId,
          currentPosition!.latitude,
          currentPosition!.longitude,
        );

        // Update location every 5 seconds for real-time tracking
        locationTimer =
            Timer.periodic(const Duration(seconds: 5), (timer) async {
          await _getCurrentLocation();
          if (currentPosition != null) {
            // Broadcast location update to all connected taxis
            socketService.broadcastLocationUpdate(
              taxId,
              currentPosition!.latitude,
              currentPosition!.longitude,
            );
            _fetchNearbyTaxis();
            _buildMapMarkers();
          }
        });

        setState(() {
          isSharingLocation = true;
        });
      }
    });
  }

  void _buildMapMarkers() {
    if (currentPosition == null) return;

    final LatLng current =
        LatLng(currentPosition!.latitude, currentPosition!.longitude);

    final currentMarker = Marker(
      point: current,
      width: 80,
      height: 80,
      // Newer versions of `Marker` use `child` instead of `builder`.
      child: const Icon(
        Icons.person_pin_circle,
        color: Colors.blue,
        size: 40,
      ),
    );

    final taxiMarkers = nearbyTaxis.map((taxi) {
      final lat = (taxi['lat'] is num ? (taxi['lat'] as num).toDouble() : 0.0);
      final lng = (taxi['lng'] is num ? (taxi['lng'] as num).toDouble() : 0.0);
      final status = taxi['status'] ?? 'nearby';
      final Color color;
      if (status == 'on_way') {
        color = Colors.green;
      } else if (status == 'arrived') {
        color = Colors.orange;
      } else {
        color = Colors.red;
      }

      return Marker(
        point: LatLng(lat, lng),
        width: 60,
        height: 60,
        child: Icon(
          Icons.local_taxi,
          color: color,
          size: 34,
        ),
      );
    }).toList();

    final List<Marker> markers = [currentMarker, ...taxiMarkers];

    if (emergencyLocation != null) {
      markers.add(
        Marker(
          point: emergencyLocation!,
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: _openEmergencyNavigation,
            child: const Icon(
              Icons.warning,
              color: Colors.redAccent,
              size: 40,
            ),
          ),
        ),
      );
    }

    // Add helper markers on the map (visible to everyone - requester and other helpers)
    _helperLocations.forEach((helperId, helperLatLng) {
      final displayName = _helperNames[helperId] ?? helperId;
      markers.add(
        Marker(
          point: helperLatLng,
          width: 80,
          height: 80,
          child: const Icon(
            Icons.directions_car,
            color: Colors.green,
            size: 40,
          ),
        ),
      );
    });

    setState(() {
      _markers = markers;
      _polylines = [];
    });

    // Build polylines from stored helper polylines (for requester to see)
    if (activeEmergencyRequesterId == taxId && _helperPolylines.isNotEmpty) {
      final List<Polyline> helperPolylines = [];
      int colorIndex = 0;
      final List<Color> polylineColors = [
        Colors.deepOrange,
        Colors.blueAccent,
        Colors.purple,
        Colors.teal,
        Colors.amber,
        Colors.indigo,
      ];
      _helperPolylines.forEach((helperId, points) {
        final displayName = _helperNames[helperId] ?? helperId;
        helperPolylines.add(
          Polyline(
            points: points,
            strokeWidth: 5.0,
            color: polylineColors[colorIndex % polylineColors.length],
          ),
        );
        colorIndex++;
      });
      setState(() {
        _polylines = helperPolylines;
      });
    }

    // If there's an active emergency (not by this taxi), try to fetch a real route
    if (activeEmergencyRequesterId != null &&
        activeEmergencyRequesterId != taxId &&
        emergencyLocation != null &&
        currentPosition != null) {
      _fetchRoute(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        emergencyLocation!,
      );
    }
  }

  void _stopLocationSharing() {
    locationTimer?.cancel();
    setState(() {
      isSharingLocation = false;
    });
  }

  Future<void> _loadSavedUserProfile() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      userName = widget.userName ?? prefs.getString('user_name') ?? 'John Doe';
      taxId = widget.taxiId ?? prefs.getString('taxi_id') ?? 'Unknown';
      userMatricule = prefs.getString('user_matricule') ?? taxId;
      userEmail = prefs.getString('user_email') ?? '';
      userPhone = prefs.getString('user_phone') ?? '';
      userProfileImageUrl = prefs.getString('profile_image_url') ?? '';
      userId = prefs.getInt('user_id');
    });

    // Fetch the latest profile (phone, profile image) from the backend
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$backendBaseUrl/api/auth/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'] as Map<String, dynamic>;
          final phone = user['phone']?.toString() ?? '';
          final profileImage = user['profile_image']?.toString() ?? '';

          if (phone.isNotEmpty) {
            await prefs.setString('user_phone', phone);
          }
          if (profileImage.isNotEmpty) {
            await prefs.setString('profile_image_url', profileImage);
          }

          setState(() {
            if (phone.isNotEmpty) userPhone = phone;
            if (profileImage.isNotEmpty) userProfileImageUrl = profileImage;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  void _setupSocketListeners() {
    // Handle incoming taxi location updates
    socketService.onTaxiLocationUpdate = (data) {
      setState(() {
        final taxiId = data['taxiId'];
        final lat = data['lat'];
        final lng = data['lng'];

        // Update or add taxi to the list
        final existingIndex =
            nearbyTaxis.indexWhere((t) => t['taxi_id'] == taxiId);
        if (existingIndex >= 0) {
          nearbyTaxis[existingIndex]['lat'] = lat;
          nearbyTaxis[existingIndex]['lng'] = lng;
        } else {
          nearbyTaxis.add(
              {'taxi_id': taxiId, 'lat': lat, 'lng': lng, 'status': 'nearby'});
        }
      });
      _buildMapMarkers();
    };

    // Handle incoming orders
    socketService.onIncomingOrder = (data) {
      setState(() {
        activities.insert(0, {
          "title": "Incoming order from ${data['fromTaxiId']}",
          "time": _currentActivityTime(),
        });
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incoming Order Request'),
          content: Text(
              'Taxi ${data['fromTaxiId']} needs ${data['reason']}\n\nLocation: ${data['lat']}, ${data['lng']}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () {
                socketService.acceptOrder('order_1', taxId, data['fromTaxiId']);
                Navigator.pop(context);
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    };

    // Handle order status updates
    socketService.onOrderStatusUpdate = (data) {
      setState(() {
        activities.insert(0, {
          "title": "Order ${data['status']}: ${data['taxiId']}",
          "time": _currentActivityTime(),
        });
      });
    };

    socketService.onEmergencyAlert = (data) {
      final incomingTaxiId = data['taxiId'] as String?;
      final incomingTaxiLabel = data['taxiNumber'] as String? ?? incomingTaxiId;
      if (incomingTaxiId != null) {
        final latValue = data['lat'];
        final lngValue = data['lng'];
        final double? emergencyLat =
            latValue is num ? latValue.toDouble() : null;
        final double? emergencyLng =
            lngValue is num ? lngValue.toDouble() : null;

        setState(() {
          activeEmergencyRequesterId = incomingTaxiId;
          activeEmergencyRequesterName = incomingTaxiLabel;
          emergencyDetails = {
            'taxiNumber': data['taxiNumber'] ?? incomingTaxiLabel,
            'driverName': data['driverName'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'taxiMatricule': data['taxiMatricule'] ?? '',
            'pictureUrl': data['pictureUrl'] ?? '',
            'message': data['message'] ?? '',
          };

          if (emergencyLat != null && emergencyLng != null) {
            emergencyLocation = LatLng(emergencyLat, emergencyLng);

            // Automatically fetch route if we are not the one in danger
            if (incomingTaxiId != taxId && currentPosition != null) {
              _fetchRoute(
                LatLng(currentPosition!.latitude, currentPosition!.longitude),
                emergencyLocation!,
              );
            }
          }

          // populate current helper set for this request if known
          final helpers = helpersByRequest[incomingTaxiId] ?? <String>{};
          helpersOnWay.clear();
          helpersOnWay.addAll(helpers);

          activities.insert(0, {
            "title": incomingTaxiId == taxId
                ? "Your emergency alert is active"
                : "Emergency request from $incomingTaxiLabel",
            "time": _currentActivityTime(),
          });
        });
      }
    };

    socketService.onHelpOnWayUpdate = (data) {
      final requestingTaxiId = data['requestingTaxiId'] as String?;
      final helperTaxiId = data['helperTaxiId'] as String?;
      final helperTaxiNumber =
          data['helperTaxiNumber'] as String? ?? helperTaxiId ?? 'Unknown taxi';
      final helperLat =
          data['lat'] is num ? (data['lat'] as num).toDouble() : null;
      final helperLng =
          data['lng'] is num ? (data['lng'] as num).toDouble() : null;

      if (requestingTaxiId != null && helperTaxiId != null) {
        // record helper for that request (store the taxi number for display)
        helpersByRequest.putIfAbsent(requestingTaxiId, () => <String>{});
        helpersByRequest[requestingTaxiId]!.add(helperTaxiNumber);

        // Store helper location and name for map display
        if (helperLat != null && helperLng != null) {
          _helperLocations[helperTaxiId] = LatLng(helperLat, helperLng);
          _helperNames[helperTaxiId] = helperTaxiNumber;
        }
      }

      setState(() {
        // if current user is the request owner, update visible helper set
        if (requestingTaxiId == taxId) {
          helpersOnWay.add(helperTaxiNumber);
        }

        // if current UI is showing a particular active requester, keep the helpers list in sync
        if (activeEmergencyRequesterId != null &&
            activeEmergencyRequesterId == requestingTaxiId) {
          helpersOnWay.clear();
          helpersOnWay.addAll(helpersByRequest[requestingTaxiId] ?? <String>{});
        }

        // if current user is the helper, request a routed path to the emergency
        if (requestingTaxiId != null &&
            requestingTaxiId == activeEmergencyRequesterId &&
            helperTaxiId == taxId &&
            emergencyLocation != null &&
            currentPosition != null) {
          _fetchRoute(
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
            emergencyLocation!,
          );
        }

// If current user is the requester (in danger), fetch route for each helper
        if (requestingTaxiId == taxId &&
            helperLat != null &&
            helperLng != null &&
            emergencyLocation != null &&
            helperTaxiId != null) {
          _fetchHelperRoute(
              helperTaxiId, LatLng(helperLat, helperLng), emergencyLocation!);
        }

        activities.insert(0, {
          "title": "Taxi $helperTaxiNumber is coming to help",
          "time": _currentActivityTime(),
        });
      });

      NotificationService.showNotification(
        title: 'Taxi Help Update',
        body: 'Taxi $helperTaxiNumber is on the way',
        type: 'update',
      );
    };

    socketService.onEmergencyCleared = (data) {
      final clearedTaxiId = data['taxiId'] as String?;
      if (clearedTaxiId == null) return;

      setState(() {
        // Remove stored helpers mapping for the cleared request
        helpersByRequest.remove(clearedTaxiId);

        // If the current UI is showing that emergency, clear it
        if (clearedTaxiId == activeEmergencyRequesterId) {
          isInDanger = false;
          activeEmergencyRequesterId = null;
          activeEmergencyRequesterName = null;
          emergencyLocation = null;
          emergencyDetails = null;
          _emergencyDistance = null;
          _emergencyDuration = null;
          helpersOnWay.clear();
          _polylines.clear();
        }

        activities.insert(0, {
          "title": "Emergency cleared for $clearedTaxiId",
          "time": _currentActivityTime(),
        });
      });
    };

    // Handle taxi going offline
    socketService.onTaxiOffline = (taxiId) {
      setState(() {
        nearbyTaxis.removeWhere((t) => t['taxi_id'] == taxiId);
      });
      _buildMapMarkers();
    };
  }

  String _currentActivityTime() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return 'Today - $hour:$minute $period';
  }

  void sendEmergencyAlert() {
    final displayLabel = userMatricule.isNotEmpty ? userMatricule : taxId;
    setState(() {
      isInDanger = true;
      activeEmergencyRequesterId = taxId;
      activeEmergencyRequesterName = displayLabel;
      helpersOnWay.clear();
      activities.insert(0, {
        "title": "Emergency alert sent",
        "time": _currentActivityTime(),
      });
    });

    sendEmergency();
    socketService.sendEmergency(
      taxId,
      currentPosition?.latitude ?? 0,
      currentPosition?.longitude ?? 0,
      'Help! My taxi $displayLabel needs assistance.',
      taxiNumber: displayLabel,
      driverName: userName,
      email: userEmail,
      phone: userPhone,
      taxiMatricule: userMatricule,
      pictureUrl: userProfileImageUrl,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Emergency alert sent to nearby taxmen"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void stopEmergencyAlert() {
    // Stop location sharing so the driver is no longer tracked on the map
    _stopLocationSharing();

    socketService.sendEmergencyCleared(
      taxId,
      driverName: userName,
      taxiMatricule: userMatricule,
      taxiNumber: userMatricule.isNotEmpty ? userMatricule : taxId,
      email: userEmail,
    );

    setState(() {
      isInDanger = false;
      activeEmergencyRequesterId = null;
      activeEmergencyRequesterName = null;
      emergencyLocation = null;
      emergencyDetails = null;
      _emergencyDistance = null;
      _emergencyDuration = null;
      helpersOnWay.clear();
      _polylines.clear();
      activities.insert(0, {
        "title": "Emergency alert stopped - You are now safe",
        "time": _currentActivityTime(),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Emergency alert stopped — You are safe now. All nearby vehicles have been notified."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void toggleEmergencyAlert() {
    if (isInDanger) {
      stopEmergencyAlert();
      return;
    }

    sendEmergencyAlert();
  }

  void sendHelpOnWay() {
    if (activeEmergencyRequesterId == null ||
        activeEmergencyRequesterId == taxId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active emergency request available to help.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    socketService.sendHelpOnWay(
      activeEmergencyRequesterId!,
      taxId,
      currentPosition?.latitude ?? 0,
      currentPosition?.longitude ?? 0,
      emergencyLat: emergencyLocation?.latitude,
      emergencyLng: emergencyLocation?.longitude,
    );

    // optimistic local update: add self to helper set for the request
    if (activeEmergencyRequesterId != null) {
      helpersByRequest.putIfAbsent(
          activeEmergencyRequesterId!, () => <String>{});
      helpersByRequest[activeEmergencyRequesterId!]!.add(taxId);
      setState(() {
        helpersOnWay.clear();
        helpersOnWay.addAll(
            helpersByRequest[activeEmergencyRequesterId!] ?? <String>{});
        if (emergencyLocation != null && currentPosition != null) {
          // request a detailed route from routing API
          _fetchRoute(
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
            emergencyLocation!,
          );
        }
        activities.insert(0, {
          "title": "You are coming to help Taxi $activeEmergencyRequesterName",
          "time": _currentActivityTime(),
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Help is on the way. Notification sent.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openEmergencyNavigation() async {
    if (emergencyLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency location is not available.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acquiring your location...'),
        ),
      );
      await _getCurrentLocation();
      if (currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationError ??
                'Unable to acquire your location. Enable GPS and try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyNavigationPage(
          responderLocation:
              LatLng(currentPosition!.latitude, currentPosition!.longitude),
          emergencyLocation: emergencyLocation!,
          requesterName: emergencyDetails?['driverName']?.toString() ??
              activeEmergencyRequesterName ??
              'Driver in danger',
          taxiId: emergencyDetails?['taxiNumber']?.toString() ??
              activeEmergencyRequesterId ??
              'Unknown taxi',
          message: emergencyDetails?['message']?.toString(),
          requesterPhone: emergencyDetails?['phone']?.toString(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSavedUserProfile();
    socketService.connect();
    _setupSocketListeners();

    // Start polling for emergency alerts (fallback for Vercel serverless)
    _emergencyPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollEmergencyAlerts();
    });

    // Get current location first
    _getCurrentLocation().then((_) {
      if (currentPosition != null) {
        // Register taxi in the system
        socketService.registerTaxi(
          taxId,
          currentPosition!.latitude,
          currentPosition!.longitude,
        );

        // Start location sharing
        _startLocationSharing();

        // Fetch and display nearby taxis
        _fetchNearbyTaxis();
        _buildMapMarkers();
      }
    });
  }

  @override
  void dispose() {
    socketService.socket.dispose();
    locationTimer?.cancel();
    _emergencyPollTimer?.cancel();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Taximan Dashboard",
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.yellow),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? _homeContent()
          : _selectedIndex == 1
              ? const AboutPage()
              : _selectedIndex == 2
                  ? const ChatPage()
                  : const NotificationPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white70,
        backgroundColor: Colors.black,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "About"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Chat"),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: "Alerts"),
        ],
      ),
    );
  }

  Widget _homeContent() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Positioned.fill(
                child: currentPosition == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.yellow,
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          // `flutter_map` newer versions use `initialCenter` and
                          // `initialZoom` instead of `center`/`zoom`.
                          initialCenter: LatLng(currentPosition!.latitude,
                              currentPosition!.longitude),
                          initialZoom: _defaultZoom,
                          maxZoom: 18,
                          minZoom: 3,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.taxi_app',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(currentPosition!.latitude,
                                    currentPosition!.longitude),
                                color: Colors.yellow.withOpacity(0.2),
                                borderColor: Colors.yellow,
                                borderStrokeWidth: 2,
                                radius: 500,
                              ),
                            ],
                          ),
                          if (_polylines.isNotEmpty)
                            PolylineLayer(polylines: _polylines),
                          MarkerLayer(markers: _markers),
                        ],
                      ),
              ),
              if (locationError != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_off,
                              size: 48, color: Colors.yellow),
                          const SizedBox(height: 16),
                          Text(
                            locationError!,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _emergencyButton(),
                const SizedBox(height: 12),
                _helpOnWayButton(),
                if (activeEmergencyRequesterId != null &&
                    activeEmergencyRequesterId != taxId)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Center(
                      child: Text(
                        'Active emergency request from ${activeEmergencyRequesterName ?? activeEmergencyRequesterId}',
                        style: const TextStyle(
                          color: Colors.lightGreenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (helpersOnWay.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Center(
                      child: Text(
                        'Helpers on the way: ${helpersOnWay.length}',
                        style: const TextStyle(
                          color: Colors.lightGreenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                  children: [
                    _quickAction(Icons.map, "Refresh Map", onTap: () {
                      _getCurrentLocation();
                      _fetchNearbyTaxis();
                      _buildMapMarkers();
                      if (currentPosition != null) {
                        _mapController.move(
                          LatLng(currentPosition!.latitude,
                              currentPosition!.longitude),
                          _defaultZoom,
                        );
                      }
                    }),
                    _quickAction(Icons.location_on, "Share\nLocation",
                        onTap: _shareLocation),
                    _quickAction(Icons.group, "Nearby\nTaximen",
                        onTap: _fetchNearbyTaxis),
                    _quickAction(Icons.support_agent, "Assistance",
                        onTap: sendEmergencyAlert),
                  ],
                ),
                const SizedBox(height: 16),
                if (activeEmergencyRequesterId != null) _emergencyAlertCard(),
                if (helpersOnWay.isNotEmpty) _helpersOnWayCard(),
                const SizedBox(height: 16),
                _activityHistory(),
                const SizedBox(height: 16),
                _nearbyTaxisSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.yellow,
                child: Icon(Icons.person, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow,
                    ),
                  ),
                  Text(
                    "Matricule: $userMatricule",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    isOnline ? "Online" : "Offline",
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Share Location",
                style: TextStyle(color: Colors.white),
              ),
              Switch(
                value: isSharingLocation,
                activeThumbColor: Colors.yellow,
                inactiveThumbColor: Colors.grey,
                activeTrackColor: Colors.yellow.withOpacity(0.5),
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                onChanged: (value) {
                  if (value) {
                    _startLocationSharing();
                  } else {
                    _stopLocationSharing();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emergencyButton() {
    return Center(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isSOSHovered = true),
        onExit: (_) => setState(() => _isSOSHovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: _isSOSHovered ? 1.15 : 1.0,
          child: GestureDetector(
            onTap: toggleEmergencyAlert,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSOSHovered ? 190 : 170,
              height: _isSOSHovered ? 190 : 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isInDanger ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (isInDanger ? Colors.green : Colors.red)
                        .withOpacity(0.7),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "SOS",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: isInDanger ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isInDanger ? "SAFE" : "HELP",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isInDanger ? Colors.black : Colors.white,
                      ),
                    ),
                    if (helpersOnWay.isNotEmpty && isInDanger) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${helpersOnWay.length} taxi(s) coming to help',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: _cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.yellow),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpOnWayButton() {
    return Center(
      child: InkWell(
        onTap: () {
          sendHelpOnWay();
          _openEmergencyNavigation();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'I am coming',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emergencyAlertCard() {
    final bool isRequester = activeEmergencyRequesterId == taxId;
    final String title =
        isRequester ? 'Emergency request sent' : 'Emergency alert received';
    final String timeDist = !isRequester && _emergencyDistance != null
        ? ' • ${_formatEmergencyDuration()} (${_formatEmergencyDistance()})'
        : '';
    final String subtitle = isRequester
        ? 'Your alert is active. Waiting for drivers to respond.'
        : 'Taxi ${activeEmergencyRequesterName ?? activeEmergencyRequesterId} needs help$timeDist.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRequester ? Colors.red.shade900 : Colors.orange.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),

          // Show requester details to other drivers
          if (!isRequester && emergencyDetails != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.yellow,
                    child: emergencyDetails!['pictureUrl'] != null
                        ? ClipOval(
                            child: Image.network(
                              emergencyDetails!['pictureUrl'],
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                          )
                        : Text(
                            (emergencyDetails!['driverName'] ?? '')
                                .toString()
                                .split(' ')
                                .map((s) => s.isNotEmpty ? s[0] : '')
                                .take(2)
                                .join(),
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emergencyDetails!['driverName'] ?? 'Unknown driver',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Taxi: ${emergencyDetails!['taxiNumber'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Email: ${emergencyDetails!['email'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${emergencyDetails!['phone'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matricule: ${emergencyDetails!['taxiMatricule'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (!isRequester)
            Text(
              'Tap "I am coming" to respond and notify the requester.',
              style: const TextStyle(color: Colors.white70),
            ),

          if (!isRequester && emergencyLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _openEmergencyNavigation,
                icon: const Icon(Icons.map),
                label: const Text('View emergency location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ),

          if (isRequester)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: stopEmergencyAlert,
                child: const Text(
                  'Cancel Emergency',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _helpersOnWayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Helpers on the way',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${helpersOnWay.length} taxi(s) are coming to help.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: helpersOnWay
                .map((helper) => Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        helper,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _activityHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Activity",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    activities.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Activity history cleared"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  "Clear",
                  style: TextStyle(color: Colors.yellow),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.yellow),
          if (activities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "No recent activities",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            ...activities.map(
              (activity) => ListTile(
                leading: const Icon(Icons.notifications, color: Colors.yellow),
                title: Text(
                  activity["title"]!,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  activity["time"]!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nearbyTaxisSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nearby Taximen",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.yellow,
            ),
          ),
          const Divider(color: Colors.yellow),
          if (nearbyTaxis.isEmpty)
            const Text(
              "No nearby taximen found.",
              style: TextStyle(color: Colors.white),
            )
          else
            ...nearbyTaxis.map(
              (taxi) => ListTile(
                leading: const Icon(Icons.local_taxi, color: Colors.yellow),
                title: Text(
                  "Matricule: ${taxi['license_plate'] ?? taxi['taxi_id']}",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  "Driver: ${taxi['driver_name'] ?? 'Unknown'} • Lat: ${taxi['lat']}, Lng: ${taxi['lng']}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.grey.shade900,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.yellow, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Colors.black54,
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    );
  }
}
