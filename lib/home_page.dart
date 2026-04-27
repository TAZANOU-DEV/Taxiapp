import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../service/socket_service.dart';
import 'about_page.dart';
import 'settings_page.dart';
import 'notification.dart';
import 'chat_page.dart';
import 'notification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String userName = "John Doe";
  String taxId = "CM-TX-4589";
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
  final Set<String> helpersOnWay = {};

  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  final double _defaultZoom = 15.0;
  final SocketService socketService = SocketService();

  List<Map<String, String>> activities = [
    {"title": "Emergency alert sent", "time": "Today - 10:45 AM"},
    {"title": "Location shared", "time": "Yesterday - 6:12 PM"},
  ];

  String get backendBaseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://10.0.2.2:3000';
  }

  Future<void> sendEmergency() async {
    try {
      if (currentPosition == null) {
        await _getCurrentLocation();
      }
      if (currentPosition == null) {
        final errorMessage =
            'Unable to send emergency because location is unavailable.';
        debugPrint(errorMessage);
        NotificationService.showNotification(
          title: 'Emergency Failed',
          body: errorMessage,
          type: 'emergency',
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/taxi/emergency'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taxiId': taxId,
          'lat': currentPosition?.latitude,
          'lng': currentPosition?.longitude,
          'message': 'Emergency alert from taxi $taxId'
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
      builder: (ctx) => const Icon(
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
        builder: (ctx) => Icon(
          Icons.local_taxi,
          color: color,
          size: 34,
        ),
      );
    }).toList();

    setState(() {
      _markers = [currentMarker, ...taxiMarkers];
    });
  }

  void _stopLocationSharing() {
    locationTimer?.cancel();
    setState(() {
      isSharingLocation = false;
    });
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
      if (incomingTaxiId != null && incomingTaxiId != taxId) {
        setState(() {
          activeEmergencyRequesterId = incomingTaxiId;
          activeEmergencyRequesterName = incomingTaxiLabel;
          activities.insert(0, {
            "title": "Emergency request from $incomingTaxiLabel",
            "time": _currentActivityTime(),
          });
        });
      }
    };

    socketService.onHelpOnWayUpdate = (data) {
      final requestingTaxiId = data['requestingTaxiId'] as String?;
      final helperTaxiId = data['helperTaxiId'] as String?;
      final helperTaxiLabel = helperTaxiId ?? 'Unknown taxi';

      setState(() {
        if (requestingTaxiId == taxId && helperTaxiId != null) {
          helpersOnWay.add(helperTaxiId);
        }
        activities.insert(0, {
          "title": "$helperTaxiLabel is coming to help",
          "time": _currentActivityTime(),
        });
      });

      NotificationService.showNotification(
        title: 'Taxi Help Update',
        body: '$helperTaxiLabel is on the way',
        type: 'update',
      );
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
    setState(() {
      isInDanger = true;
      activeEmergencyRequesterId = taxId;
      activeEmergencyRequesterName = taxId;
      helpersOnWay.clear();
      activities.insert(0, {
        "title": "Emergency alert sent",
        "time": _currentActivityTime(),
      });
    });

    sendEmergency();
    socketService.sendEmergency(taxId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Emergency alert sent to nearby taxmen"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void stopEmergencyAlert() {
    setState(() {
      isInDanger = false;
      activeEmergencyRequesterId = null;
      activeEmergencyRequesterName = null;
      helpersOnWay.clear();
      activities.insert(0, {
        "title": "Emergency alert stopped",
        "time": _currentActivityTime(),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Emergency alert stopped"),
        backgroundColor: Colors.green,
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
    );

    setState(() {
      activities.insert(0, {
        "title": "You are coming to help Taxi ${activeEmergencyRequesterName}",
        "time": _currentActivityTime(),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Help is on the way. Notification sent.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    socketService.connect();
    _setupSocketListeners();

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
          flex: 5,
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
                          center: LatLng(currentPosition!.latitude,
                              currentPosition!.longitude),
                          zoom: _defaultZoom,
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
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _getCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow,
                            ),
                            child: const Text('Retry',
                                style: TextStyle(color: Colors.black)),
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
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileCard(),
                const SizedBox(height: 14),
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
                _activityHistory(),
                const SizedBox(height: 16),
                _nearbyTaxisSection(),
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
                    "Tax ID: $taxId",
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
        onTap: sendHelpOnWay,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
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
                  "Taxi ID: ${taxi['taxi_id']}",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  "Lat: ${taxi['lat']}, Lng: ${taxi['lng']}",
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
