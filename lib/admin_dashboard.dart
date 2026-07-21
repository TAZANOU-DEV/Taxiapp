import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

enum _AdminTab { overview, drivers, management }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String get baseUrl {
    return 'http://10.95.105.200:3000';
  }

  _AdminTab _selectedTab = _AdminTab.overview;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _emergencies = [];
  String _emergencyStatusFilter = 'all';
  final Map<int, String> _selectedOrderStatuses = {};
  final List<String> _orderStatusOptions = [
    'requested',
    'accepted',
    'on_way',
    'arrived',
    'completed',
    'cancelled',
  ];

  int get _totalDrivers =>
      int.tryParse(_stats['total_drivers']?.toString() ?? '') ?? 0;
  int get _onlineDrivers =>
      int.tryParse(_stats['online_taxis']?.toString() ?? '') ?? 0;
  int get _totalTaxis =>
      int.tryParse(_stats['total_taxis']?.toString() ?? '') ?? 0;
  int get _activeOrders =>
      int.tryParse(_stats['active_orders']?.toString() ?? '') ?? _orders.length;
  int get _completedOrders =>
      int.tryParse(_stats['completed_orders']?.toString() ?? '') ?? 0;
  int get _todayEmergencies =>
      int.tryParse(_stats['today_emergencies']?.toString() ?? '') ??
      _emergencies.length;
  int get _totalOrders =>
      int.tryParse(_stats['total_orders']?.toString() ?? '') ?? _orders.length;
  double get _completionRate =>
      _totalOrders > 0 ? _completedOrders / _totalOrders : 0.0;
  double get _availabilityRate =>
      _totalDrivers > 0 ? _onlineDrivers / _totalDrivers : 0.0;

  Map<String, int> get _dailyRequestsLast7 {
    final now = DateTime.now();
    final Map<String, int> counts = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      counts[key] = 0;
    }
    for (final order in _orders) {
      final created = order['created_at']?.toString();
      if (created == null) continue;
      DateTime? dt;
      try {
        dt = DateTime.parse(created);
      } catch (_) {
        try {
          dt = DateTime.parse(created.split('.').first);
        } catch (_) {
          dt = null;
        }
      }
      if (dt == null) continue;
      final key =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return counts;
  }

  Map<String, int> get _quarterCounts {
    final Map<String, int> counts = {};
    for (final order in _orders) {
      final taxiId = order['to_taxi_id'] ?? order['from_taxi_id'];
      String region = 'Unknown';
      if (taxiId != null) {
        final taxi = _drivers.firstWhere(
            (d) => d['taxi_id']?.toString() == taxiId.toString(),
            orElse: () => {});
        final plate = taxi['license_plate']?.toString() ?? '';
        if (plate.isNotEmpty) {
          final parts = plate.split(' ');
          if (parts.isNotEmpty) region = parts[0];
        }
      }
      counts[region] = (counts[region] ?? 0) + 1;
    }
    return counts;
  }

  int get _taxisInDanger {
    final Set<String> ids = {};
    for (final e in _emergencies) {
      final status = e['status']?.toString() ?? '';
      if (status.toLowerCase() != 'resolved') {
        final id = e['taxi_id']?.toString();
        if (id != null) ids.add(id);
      }
    }
    return ids.length;
  }

  int _orderCountByStatus(String status) {
    return _orders
        .where((order) => order['status']?.toString() == status)
        .length;
  }

  int _emergencyCountByStatus(String status) {
    return _emergencies
        .where((item) => item['status']?.toString() == status)
        .length;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.blue;
      case 'accepted':
        return Colors.indigo;
      case 'on_way':
        return Colors.orange;
      case 'arrived':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _logout();
      return {};
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchStats(),
        _fetchDrivers(),
        _fetchOrders(),
        _fetchEmergencies(),
      ]);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStats() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;

    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/stats'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Stats request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to fetch stats');
    }

    setState(() {
      _stats = Map<String, dynamic>.from(data['stats'] ?? {});
    });
  }

  Future<void> _fetchDrivers() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;

    final response = await http.get(
      Uri.parse('$baseUrl/api/drivers?limit=100'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Drivers request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to fetch drivers');
    }

    setState(() {
      _drivers = List<Map<String, dynamic>>.from(data['drivers'] ?? []);
    });
  }

  Future<void> _fetchOrders() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;

    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/orders?limit=50'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Orders request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to fetch orders');
    }

    setState(() {
      _orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
    });
  }

  Future<void> _fetchEmergencies() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;

    final queryParams = <String, String>{'limit': '50'};
    if (_emergencyStatusFilter != 'all') {
      queryParams['status'] = _emergencyStatusFilter;
    }

    final uri = Uri.parse('$baseUrl/api/admin/emergencies')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Emergency request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to fetch emergencies');
    }

    setState(() {
      _emergencies = List<Map<String, dynamic>>.from(data['emergencies'] ?? []);
    });
  }

  Future<void> _updateTaxiStatus(String taxiId, bool isOnline) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;

    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/taxi/$taxiId/status'),
      headers: headers,
      body: jsonEncode({'isOnline': isOnline}),
    );

    if (response.statusCode != 200) {
      _showSnackBar('Failed to update taxi status (${response.statusCode})');
      return;
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      _showSnackBar(data['error'] ?? 'Failed to update taxi status');
      return;
    }

    _showSnackBar('Taxi $taxiId is now ${isOnline ? 'online' : 'offline'}',
        color: Colors.green);
    await _fetchDrivers();
    await _fetchStats();
  }

  Future<void> _launchPhone(String? phoneRaw) async {
    if (phoneRaw == null) return;
    final phone = phoneRaw.replaceAll(RegExp(r'[^+\d]'), '');
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (e) {
      _showSnackBar('Could not launch phone app: $e');
    }
  }

  Future<void> _launchWhatsApp(String? phoneRaw, {String? message}) async {
    if (phoneRaw == null) return;
    var digits = phoneRaw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return;
    // wa.me expects country code + number without plus
    final uri = Uri.parse(
        'https://wa.me/$digits${message != null ? '?text=${Uri.encodeComponent(message)}' : ''}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open WhatsApp: $e');
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;

    final response = await http.put(
      Uri.parse('$baseUrl/api/taxi-orders/$orderId/status'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      _showSnackBar('Failed to update order status (${response.statusCode})');
      return;
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      _showSnackBar(data['error'] ?? 'Failed to update order status');
      return;
    }

    _showSnackBar('Order #$orderId status updated to $status',
        color: Colors.green);
    await _fetchOrders();
    await _fetchStats();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    // Ensure any open modal routes are removed and navigate to login
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _openDriverDetail(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DrvierDetailSheet(
          driver: driver,
          onStatusToggle: (bool toOnline) {
            if (driver['taxi_id'] != null) {
              _updateTaxiStatus(driver['taxi_id'], toOnline);
            }
          },
          onCall: (phone) => _launchPhone(phone),
          onWhatsApp: (phone) => _launchWhatsApp(phone),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _selectedTab == _AdminTab.overview
              ? 'Admin Overview'
              : _selectedTab == _AdminTab.drivers
                  ? 'Drivers'
                  : 'Management',
          style: const TextStyle(color: Colors.yellow),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.yellow),
            onPressed: _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.yellow),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_error',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshAll,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildSelectedTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab.index,
        onTap: (index) {
          setState(() {
            _selectedTab = _AdminTab.values[index];
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.drive_eta),
            label: 'Drivers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Management',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case _AdminTab.drivers:
        return _buildDriversTab();
      case _AdminTab.management:
        return _buildManagementTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardHeader(),
            const SizedBox(height: 24),
            _sectionTitle('Key metrics'),
            const SizedBox(height: 12),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildOrderStatusBreakdownCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildDriverAvailabilityCard()),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDailyRequestsCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildQuarterBreakdownCard()),
              ],
            ),
            const SizedBox(height: 24),
            _buildEmergencyTrendCard(),
            const SizedBox(height: 24),
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161A2B), Color(0xFF1E213A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.yellow[700],
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.analytics, color: Colors.black, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Admin dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Insightful analytics for drivers, orders, and alerts.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _refreshAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildOverviewPill(
                  'Online drivers', '$_onlineDrivers', Colors.green),
              _buildOverviewPill(
                  'Active orders', '$_activeOrders', Colors.orange),
              _buildOverviewPill(
                  'Today alerts', '$_todayEmergencies', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
              Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriversTab() {
    return RefreshIndicator(
      onRefresh: _fetchDrivers,
      child: _drivers.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [Text('No drivers found.')],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: _drivers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDriverSummaryCard();
                }
                final driver = _drivers[index - 1];
                final isOnline =
                    driver['is_online'] == 1 || driver['is_online'] == true;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.yellow[700],
                              child: Text(
                                (driver['username'] ?? 'U')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver['username'] ?? 'Unknown driver',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    driver['email'] ?? 'No email provided',
                                    style:
                                        const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              backgroundColor: isOnline
                                  ? Colors.green[100]
                                  : Colors.grey[200],
                              label: Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: isOnline
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildDriverDetailChip(
                                'Taxi', driver['taxi_id'] ?? 'N/A'),
                            _buildDriverDetailChip(
                                'Plate', driver['license_plate'] ?? 'N/A'),
                            _buildDriverDetailChip(
                                'Phone', driver['user_phone'] ?? 'N/A'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _openDriverDetail(driver),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                ),
                                child: const Text('Details'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: driver['taxi_id'] == null
                                    ? null
                                    : () {
                                        _updateTaxiStatus(
                                            driver['taxi_id'], !isOnline);
                                      },
                                child: Text(
                                    isOnline ? 'Set Offline' : 'Set Online'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDriverSummaryCard() {
    final offlineDrivers = _totalDrivers - _onlineDrivers;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Total drivers: $_totalDrivers',
                style: const TextStyle(fontSize: 14)),
            Text('Online now: $_onlineDrivers',
                style: const TextStyle(fontSize: 14)),
            Text('Offline now: $offlineDrivers',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _availabilityRate,
              minHeight: 10,
              color: Colors.green,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(_availabilityRate * 100).round()}% available',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$offlineDrivers offline',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Order management'),
          const SizedBox(height: 12),
          if (_orders.isEmpty)
            const Text('No orders available at this time.')
          else
            Column(
              children: _orders.map(_buildOrderManagementCard).toList(),
            ),
          const SizedBox(height: 24),
          _sectionTitle('Emergency alerts'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _emergencyStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'resolved', child: Text('Resolved')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _emergencyStatusFilter = value;
                    });
                    _fetchEmergencies();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _fetchEmergencies,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_emergencies.isEmpty)
            const Text('No emergency alerts at the moment.')
          else
            Column(
              children: _emergencies.map(_buildEmergencyCard).toList(),
            ),
          const SizedBox(height: 24),
          _sectionTitle('Driver quick actions'),
          const SizedBox(height: 12),
          _buildManagementActionCard(
            'Refresh all data',
            'Reload drivers, orders, and emergency alerts.',
            Icons.refresh,
            _refreshAll,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderManagementCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? 0;
    final currentStatus = _selectedOrderStatuses[orderId] ??
        order['status']?.toString() ??
        'requested';
    final statusLabel = currentStatus.replaceAll('_', ' ').toUpperCase();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order #$orderId',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Chip(
                  backgroundColor:
                      _statusColor(currentStatus).withOpacity(0.14),
                  label: Text(statusLabel,
                      style: TextStyle(
                          color: _statusColor(currentStatus),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: currentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _orderStatusOptions
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(
                                  status.replaceAll('_', ' ').toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedOrderStatuses[orderId] = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final selectedStatus = _selectedOrderStatuses[orderId] ??
                        order['status']?.toString() ??
                        'requested';
                    _updateOrderStatus(orderId, selectedStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size(110, 56),
                  ),
                  child: const Text('Update'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('From',
                '${order['from_driver'] ?? order['from_driver_name'] ?? 'N/A'}'),
            _buildDetailRow('To',
                '${order['to_driver'] ?? order['to_driver_name'] ?? 'N/A'}'),
            _buildDetailRow('Created', '${order['created_at'] ?? 'N/A'}'),
            _buildDetailRow('Pickup',
                '${order['pickup_lat'] ?? 'N/A'}, ${order['pickup_lng'] ?? 'N/A'}'),
            _buildDetailRow('Dropoff',
                '${order['dropoff_lat'] ?? 'N/A'}, ${order['dropoff_lng'] ?? 'N/A'}'),
            _buildDetailRow('Notes', '${order['reason'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementActionCard(
      String title, String subtitle, IconData icon, VoidCallback action) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          onPressed: action,
          child: const Text('Run'),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildAnalyticsCard(
            'Total drivers', '$_totalDrivers', 'Drivers onboard', Colors.blue),
        _buildAnalyticsCard('Online taxis', '$_onlineDrivers',
            'Currently active', Colors.green),
        _buildAnalyticsCard(
            'Active orders', '$_activeOrders', 'In progress', Colors.orange),
        _buildAnalyticsCard('Completed orders', '$_completedOrders',
            'Fulfilled today', Colors.purple),
        _buildAnalyticsCard(
            'Total taxis', '$_totalTaxis', 'Fleet size', Colors.cyan),
        _buildAnalyticsCard('Today alerts', '$_todayEmergencies',
            'Emergency warnings', Colors.red),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, String subtitle, Color color) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 900
          ? 280
          : MediaQuery.of(context).size.width / 2 - 28,
      child: HoverCard(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              Text(value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatusBreakdownCard() {
    final statuses = [
      'requested',
      'accepted',
      'on_way',
      'arrived',
      'completed',
      'cancelled'
    ];
    final counts = statuses.map(_orderCountByStatus).toList();
    final maxCount =
        counts.fold<int>(1, (prev, value) => value > prev ? value : prev);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order status breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...List.generate(statuses.length, (index) {
              final status = statuses[index];
              final count = counts[index];
              final widthFactor = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(status.replaceAll('_', ' ').toUpperCase()),
                        Text('$count',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: widthFactor,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation(_statusColor(status)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_totalOrders == 0)
              const Text('No order data available yet.',
                  style: TextStyle(color: Colors.black54))
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Total tracked orders: $_totalOrders',
                    style: const TextStyle(color: Colors.black54)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverAvailabilityCard() {
    final offlineDrivers = _totalDrivers - _onlineDrivers;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: _availabilityRate,
                      strokeWidth: 14,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(Colors.green),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(_availabilityRate * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Available',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildStatusPill('Online', '$_onlineDrivers', Colors.green),
            const SizedBox(height: 10),
            _buildStatusPill('Offline', '$offlineDrivers', Colors.grey),
            const SizedBox(height: 10),
            _buildStatusPill('Fleet size', '$_totalTaxis', Colors.cyan),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTrendCard() {
    final statuses = [
      'requested',
      'accepted',
      'on_way',
      'arrived',
      'completed',
      'cancelled'
    ];
    final counts = statuses.map(_orderCountByStatus).toList();
    final pending = _emergencyCountByStatus('pending');
    final resolved = _emergencyCountByStatus('resolved');
    final totalAlerts = _emergencies.length;
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business insights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPieChartSection(statuses, counts)),
                const SizedBox(width: 18),
                Expanded(
                    child: _buildAlertOverviewSection(
                        pending, resolved, totalAlerts)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection(List<String> statuses, List<int> counts) {
    final total = counts.fold<int>(0, (sum, value) => sum + value);
    final data = List.generate(statuses.length, (index) {
      return {
        'label': statuses[index].replaceAll('_', ' ').toUpperCase(),
        'count': counts[index],
        'color': _statusColor(statuses[index]),
      };
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order status split',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _PieChartPainter(
                values: counts.map((count) => count.toDouble()).toList(),
                colors: data.map((item) => item['color'] as Color).toList(),
              ),
              child: Center(
                child: Text(
                  '$total',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: data
              .where((segment) => segment['count'] as int > 0)
              .map((segment) => _buildLegendItem(
                    segment['label'] as String,
                    segment['count'] as int,
                    segment['color'] as Color,
                    total,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAlertOverviewSection(
      int pending, int resolved, int totalAlerts) {
    final maxAlert = totalAlerts > 0 ? totalAlerts : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alert response metrics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _buildStatusPill('Pending', '$pending', Colors.orange),
        const SizedBox(height: 10),
        _buildStatusPill('Resolved', '$resolved', Colors.green),
        const SizedBox(height: 16),
        const Text('Alert trend',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBarIndicator('Pending', pending, maxAlert, Colors.orange),
                const SizedBox(width: 12),
                _buildBarIndicator(
                    'Resolved', resolved, maxAlert, Colors.green),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Total alerts: $totalAlerts',
            style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _buildDailyRequestsCard() {
    final data = _dailyRequestsLast7.entries.toList();
    final total = data.fold<int>(0, (s, e) => s + e.value);
    final maxVal = data.fold<int>(1, (p, e) => e.value > p ? e.value : p);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Requests (last 7 days)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((entry) {
                  final val = entry.value;
                  final height = maxVal > 0 ? (val / maxVal) * 90.0 : 8.0;
                  final label = entry.key.split('-').sublist(1).join('/');
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height < 8.0 ? 8.0 : height,
                          width: 14,
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('$val', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(label, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Total: $total',
                style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterBreakdownCard() {
    final counts = _quarterCounts;
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top quarters',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('No location data available',
                  style: TextStyle(color: Colors.black54))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entries
                    .take(6)
                    .map((e) => Chip(label: Text('${e.key} • ${e.value}')))
                    .toList(),
              ),
            const SizedBox(height: 10),
            Text('Taxis in danger: $_taxisInDanger',
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarIndicator(
      String label, int value, int maxValue, Color color) {
    final heightFactor = maxValue > 0 ? value / maxValue : 0.0;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: 80 * heightFactor + 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$value',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text('${((heightFactor) * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color, int total) {
    final percentage = total > 0 ? ((count / total) * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$label • $count ($percentage%)',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAlertSparkline() {
    final counts = [
      _emergencyCountByStatus('pending'),
      _emergencyCountByStatus('resolved'),
      _emergencyCountByStatus('pending'),
      _emergencyCountByStatus('resolved'),
    ];
    final maxCount =
        counts.fold<int>(1, (prev, value) => value > prev ? value : prev);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: counts.map((count) {
        final double barHeight = maxCount > 0 ? (count / maxCount) * 90.0 : 8.0;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: barHeight < 12.0 ? 12.0 : barHeight,
                width: 12,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text('$count',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent activity'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRecentOrdersPreview()),
            const SizedBox(width: 16),
            Expanded(child: _buildRecentAlertsPreview()),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrdersPreview() {
    final recentOrders = _orders.take(3).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Latest orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (recentOrders.isEmpty)
              const Text('No recent orders available.',
                  style: TextStyle(color: Colors.black54))
            else
              ...recentOrders.map((order) {
                final status = order['status']?.toString() ?? 'unknown';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${order['id'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                order['from_driver'] ??
                                    order['from_driver_name'] ??
                                    'Unknown driver',
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      Chip(
                        backgroundColor: _statusColor(status).withOpacity(0.16),
                        label: Text(status.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(color: _statusColor(status))),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlertsPreview() {
    final recentAlerts = _emergencies.take(3).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Latest alerts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (recentAlerts.isEmpty)
              const Text('No recent alerts.',
                  style: TextStyle(color: Colors.black54))
            else
              ...recentAlerts.map((alert) {
                final status = alert['status']?.toString() ?? 'unknown';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert['message']?.toString() ?? 'New alert',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Taxi ${alert['taxi_id'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(width: 8),
                          Chip(
                            backgroundColor:
                                _statusColor(status).withOpacity(0.16),
                            label: Text(status.toUpperCase(),
                                style: TextStyle(color: _statusColor(status))),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(title, style: const TextStyle(color: Colors.black54))),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDriverDetailChip(String label, String value) {
    if (label.toLowerCase() == 'phone' && value != 'N/A') {
      return GestureDetector(
        onTap: () => _launchPhone(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$label: $value', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _launchWhatsApp(value),
                icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
    }

    return Chip(
      backgroundColor: Colors.grey[100],
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order['id'] ?? 'N/A'}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('From driver: ${order['from_driver'] ?? 'N/A'}'),
            Text('To driver: ${order['to_driver'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Status: ${order['status'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Created at: ${order['created_at'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> emergency) {
    final driverName =
        emergency['driver_name'] ?? emergency['taxi_driver_name'] ?? 'N/A';
    final phone = emergency['taxi_phone'] ?? emergency['phone'] ?? 'N/A';
    final taxiId = emergency['taxi_id'] ?? 'N/A';
    final status = emergency['status'] ?? 'N/A';
    final message = emergency['message'] ?? 'No additional details';
    final createdAt = emergency['created_at'] ?? 'N/A';

    return HoverCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                        'Alert #${emergency['alert_id'] ?? emergency['id'] ?? 'N/A'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Chip(
                    backgroundColor:
                        _statusColor(status.toString()).withOpacity(0.16),
                    label: Text(status.toString().toUpperCase(),
                        style: TextStyle(
                            color: _statusColor(status.toString()),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDetailRow('Taxi ID', taxiId),
              _buildDetailRow('Driver', driverName),
              // Contact actions for phone
              if (phone != 'N/A')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Phone:',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Text(phone, textAlign: TextAlign.right),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _launchPhone(phone),
                        icon: const Icon(Icons.phone),
                      ),
                      IconButton(
                        onPressed: () =>
                            _launchWhatsApp(phone, message: message),
                        icon: const Icon(Icons.chat, color: Colors.green),
                      ),
                    ],
                  ),
                )
              else
                _buildDetailRow('Phone', phone),
              _buildDetailRow('Message', message),
              _buildDetailRow('Location',
                  '${emergency['latitude'] ?? emergency['lat'] ?? 'N/A'}, ${emergency['longitude'] ?? emergency['lng'] ?? 'N/A'}'),
              _buildDetailRow('Created at', createdAt),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value / $total'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total > 0 ? value / total : 0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendBars() {
    final values = [
      (_stats['online_taxis'] ?? 0) as int,
      (_stats['active_orders'] ?? 0) as int,
      (_stats['today_emergencies'] ?? 0) as int,
      (_stats['total_drivers'] ?? 0) as int,
    ];
    final labels = ['Online', 'Active', 'Emergencies', 'Drivers'];
    final maxValue =
        values.fold<int>(1, (prev, element) => element > prev ? element : prev);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(values.length, (index) {
        final value = values[index];
        final double height = maxValue > 0 ? (value / maxValue) * 120.0 : 10.0;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: height < 16.0 ? 16.0 : height,
                width: 16,
                decoration: BoxDecoration(
                  color: Colors.yellow[700],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text(labels[index], style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('$value',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }),
    );
  }
}

class HoverCard extends StatefulWidget {
  final Widget child;
  const HoverCard({required this.child, super.key});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovering = false;
  bool _pressing = false;

  void _setHover(bool hovering) {
    setState(() {
      _hovering = hovering;
    });
  }

  void _setPress(bool pressing) {
    setState(() {
      _pressing = pressing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hoverScale = _hovering || _pressing ? 1.01 : 1.0;
    final boxShadow = _hovering || _pressing
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ];

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTapDown: (_) => _setPress(true),
        onTapUp: (_) => _setPress(false),
        onTapCancel: () => _setPress(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(hoverScale),
          decoration: BoxDecoration(boxShadow: boxShadow),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweepAngle = total > 0 ? (values[i] / total) * 2 * math.pi : 0.0;
      final paint = Paint()..color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return !listEquals(values, oldDelegate.values) ||
        !listEquals(colors, oldDelegate.colors);
  }
}

class DrvierDetailSheet extends StatelessWidget {
  final Map<String, dynamic> driver;
  final void Function(bool toOnline) onStatusToggle;
  final void Function(String? phone)? onCall;
  final void Function(String? phone)? onWhatsApp;

  const DrvierDetailSheet({
    required this.driver,
    required this.onStatusToggle,
    this.onCall,
    this.onWhatsApp,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = driver['is_online'] == 1 || driver['is_online'] == true;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                driver['username'] ?? 'Driver details',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _detailRow('Email', driver['email'] ?? 'N/A'),
              _detailRow('Phone', driver['user_phone'] ?? 'N/A'),
              _detailRow('Taxi ID', driver['taxi_id'] ?? 'N/A'),
              _detailRow('License plate', driver['license_plate'] ?? 'N/A'),
              _detailRow('Online status', isOnline ? 'Online' : 'Offline'),
              _detailRow('Created at', driver['user_created_at'] ?? 'N/A'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onStatusToggle(!isOnline);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline ? Colors.red : Colors.green,
                      ),
                      child: Text(isOnline ? 'Set offline' : 'Set online'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: label.toLowerCase() == 'phone' && value != 'N/A'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(value, textAlign: TextAlign.right),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          if (onCall != null) onCall!(value);
                        },
                        icon: const Icon(Icons.phone),
                      ),
                      IconButton(
                        onPressed: () {
                          if (onWhatsApp != null) onWhatsApp!(value);
                        },
                        icon: const Icon(Icons.chat, color: Colors.green),
                      ),
                    ],
                  )
                : Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
