import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  final String taxId;
  final List<Map<String, dynamic>> nearbyTaxis;

  const MapPage({
    required this.taxId,
    required this.nearbyTaxis,
    super.key,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController _mapController;
  Position? currentPosition;
  List<Marker> _markers = [];
  Timer? locationUpdateTimer;

  final LatLng initialLocation = LatLng(3.8480, 11.5021); // Cameroon
  double currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    _updateMarkers();
    _startRealTimeTracking();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => currentPosition = position);
      _moveToCurrentLocation();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _updateMarkers() {
    final List<Marker> markers = [];

    if (currentPosition != null) {
      markers.add(
        Marker(
          width: 80,
          height: 80,
          point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          builder: (ctx) => const Icon(
            Icons.person_pin_circle,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
    }

    for (final taxi in widget.nearbyTaxis) {
      final lat = (taxi['lat'] is num ? (taxi['lat'] as num).toDouble() : 0.0);
      final lng = (taxi['lng'] is num ? (taxi['lng'] as num).toDouble() : 0.0);
      markers.add(
        Marker(
          width: 60,
          height: 60,
          point: LatLng(lat, lng),
          builder: (ctx) => const Icon(
            Icons.local_taxi,
            color: Colors.red,
            size: 35,
          ),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  void _startRealTimeTracking() {
    locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        await _getCurrentLocation();
        _updateMarkers();
      },
    );
  }

  void _moveToCurrentLocation() {
    if (currentPosition != null) {
      _mapController.move(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        currentZoom,
      );
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  void dispose() {
    locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = currentPosition != null
        ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
        : initialLocation;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title:
            const Text('Location Map', style: TextStyle(color: Colors.yellow)),
        elevation: 0,
      ),
      body: currentPosition == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.yellow),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: center,
                    zoom: currentZoom,
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
                      circles: currentPosition != null
                          ? [
                              CircleMarker(
                                point: center,
                                color: Colors.yellow.withOpacity(0.2),
                                borderColor: Colors.yellow,
                                borderStrokeWidth: 2,
                                radius: 500,
                              ),
                            ]
                          : [],
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.yellow,
                    onPressed: _moveToCurrentLocation,
                    child: const Icon(Icons.my_location, color: Colors.black),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.yellow, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nearby Taxis',
                            style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: widget.nearbyTaxis.isEmpty
                              ? const Center(
                                  child: Text('No nearby taxis',
                                      style: TextStyle(color: Colors.white)))
                              : ListView.builder(
                                  itemCount: widget.nearbyTaxis.length,
                                  itemBuilder: (context, index) {
                                    final taxi = widget.nearbyTaxis[index];
                                    final distance = currentPosition != null
                                        ? _calculateDistance(
                                                currentPosition!.latitude,
                                                currentPosition!.longitude,
                                                (taxi['lat'] is num
                                                    ? (taxi['lat'] as num)
                                                        .toDouble()
                                                    : 0.0),
                                                (taxi['lng'] is num
                                                    ? (taxi['lng'] as num)
                                                        .toDouble()
                                                    : 0.0))
                                            .toStringAsFixed(2)
                                        : 'N/A';
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Taxi ${taxi['taxi_id']} - $distance km',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
