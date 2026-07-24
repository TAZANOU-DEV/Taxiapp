import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyNavigationPage extends StatefulWidget {
  const EmergencyNavigationPage({
    required this.responderLocation,
    required this.emergencyLocation,
    required this.requesterName,
    required this.taxiId,
    this.message,
    super.key,
  });

  final LatLng responderLocation;
  final LatLng emergencyLocation;
  final String requesterName;
  final String taxiId;
  final String? message;

  @override
  State<EmergencyNavigationPage> createState() =>
      _EmergencyNavigationPageState();
}

class _EmergencyNavigationPageState extends State<EmergencyNavigationPage> {
  List<LatLng> _routePoints = [];
  double? _distanceMeters;
  double? _durationSeconds;
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (result & 1) == 1 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (result & 1) == 1 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }

  Future<void> _loadRoute() async {
    final from = widget.responderLocation;
    final to = widget.emergencyLocation;

    try {
      final response = await http.get(
        Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=polyline',
        ),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = body['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final geometry = route['geometry'] as String?;
          if (geometry != null && mounted) {
            setState(() {
              _routePoints = _decodePolyline(geometry);
              _distanceMeters = (route['distance'] as num?)?.toDouble();
              _durationSeconds = (route['duration'] as num?)?.toDouble();
              _isLoadingRoute = false;
            });
            return;
          }
        }
      }
    } catch (_) {
      // The straight line below still exposes the emergency location offline.
    }

    if (!mounted) return;
    setState(() {
      _routePoints = [from, to];
      _isLoadingRoute = false;
    });
  }

  double _initialZoom() {
    const distance = Distance();
    final kilometers = distance.as(
      LengthUnit.Kilometer,
      widget.responderLocation,
      widget.emergencyLocation,
    );
    if (kilometers < 2) return 14;
    if (kilometers < 10) return 12;
    if (kilometers < 40) return 10;
    if (kilometers < 120) return 8;
    return 6;
  }

  String _formatDistance() {
    final meters = _distanceMeters;
    if (meters == null) return 'Route being calculated';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration() {
    final seconds = _durationSeconds;
    if (seconds == null) return 'Estimated time unavailable';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  Future<void> _openGoogleMaps() async {
    final origin =
        '${widget.responderLocation.latitude},${widget.responderLocation.longitude}';
    final destination =
        '${widget.emergencyLocation.latitude},${widget.emergencyLocation.longitude}';
    final navigationUri = Uri(
      scheme: 'google.navigation',
      queryParameters: {'q': destination, 'mode': 'd'},
    );
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

    final started = await launchUrl(
      navigationUri,
      mode: LaunchMode.externalApplication,
    );
    if (started) return;

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

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (widget.responderLocation.latitude + widget.emergencyLocation.latitude) /
          2,
      (widget.responderLocation.longitude +
              widget.emergencyLocation.longitude) /
          2,
    );

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: _initialZoom(),
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.taxi_app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.black87,
                      strokeWidth: 9,
                    ),
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF512DA8),
                      strokeWidth: 6,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.responderLocation,
                    width: 58,
                    height: 58,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 38,
                    ),
                  ),
                  Marker(
                    point: widget.emergencyLocation,
                    width: 70,
                    height: 70,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 58,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 4,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EMERGENCY LOCATION',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.requesterName} • ${widget.taxiId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 16),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingRoute)
                      const LinearProgressIndicator(color: Color(0xFF512DA8))
                    else
                      Text(
                        '${_formatDuration()} • ${_formatDistance()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (widget.message != null && widget.message!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.message!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.navigation),
                        label: const Text('Start navigation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
