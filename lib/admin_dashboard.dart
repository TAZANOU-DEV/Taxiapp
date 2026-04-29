import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';

enum _AdminTab { overview, drivers, management }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000';
  }

  _AdminTab _selectedTab = _AdminTab.overview;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _emergencies = [];
  final Map<int, String> _selectedOrderStatuses = {};
  final List<String> _orderStatusOptions = [
    'requested',
    'accepted',
    'on_way',
    'arrived',
    'completed',
    'cancelled',
  ];

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

    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/emergencies?limit=20'),
      headers: headers,
    );

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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Summary'),
          const SizedBox(height: 12),
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _sectionTitle('Performance Overview'),
          const SizedBox(height: 12),
          _buildTrendsCard(),
          const SizedBox(height: 24),
          _sectionTitle('Live Driver Status'),
          const SizedBox(height: 12),
          _buildDriverStatusCard(),
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
              itemCount: _drivers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final driver = _drivers[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                driver['username'] ?? 'Unknown driver',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Chip(
                              backgroundColor: (driver['is_online'] == 1 ||
                                      driver['is_online'] == true)
                                  ? Colors.green[100]
                                  : Colors.grey[200],
                              label: Text(
                                (driver['is_online'] == 1 ||
                                        driver['is_online'] == true)
                                    ? 'Online'
                                    : 'Offline',
                                style: TextStyle(
                                  color: (driver['is_online'] == 1 ||
                                          driver['is_online'] == true)
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Email: ${driver['email'] ?? 'N/A'}'),
                        Text('Phone: ${driver['user_phone'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Taxi ID: ${driver['taxi_id'] ?? 'N/A'}'),
                        Text('Plate: ${driver['license_plate'] ?? 'N/A'}'),
                        if (driver['lat'] != null && driver['lng'] != null)
                          Text('Location: ${driver['lat']}, ${driver['lng']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _openDriverDetail(driver),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                              ),
                              child: const Text('Details'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: driver['taxi_id'] == null
                                  ? null
                                  : () {
                                      final isOnline =
                                          driver['is_online'] == 1 ||
                                              driver['is_online'] == true;
                                      _updateTaxiStatus(
                                          driver['taxi_id'], !isOnline);
                                    },
                              child: Text(
                                (driver['is_online'] == 1 ||
                                        driver['is_online'] == true)
                                    ? 'Set Offline'
                                    : 'Set Online',
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

  Widget _buildManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Order Management'),
          const SizedBox(height: 12),
          if (_orders.isEmpty)
            const Text('No orders available at this time.')
          else
            Column(
              children: _orders.map(_buildOrderManagementCard).toList(),
            ),
          const SizedBox(height: 24),
          _sectionTitle('Emergency Alerts'),
          const SizedBox(height: 12),
          if (_emergencies.isEmpty)
            const Text('No emergency alerts at the moment.')
          else
            Column(
              children: _emergencies.map(_buildEmergencyCard).toList(),
            ),
          const SizedBox(height: 24),
          _sectionTitle('Driver Quick Actions'),
          const SizedBox(height: 12),
          _buildManagementActionCard(
            'Refresh all data',
            'Reload drivers, orders, and emergency alerts from the database.',
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #$orderId',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
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
            const SizedBox(height: 14),
            Text(
                'From driver: ${order['from_driver'] ?? order['from_driver_name'] ?? 'N/A'}'),
            Text(
                'To driver: ${order['to_driver'] ?? order['to_driver_name'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Created: ${order['created_at'] ?? 'N/A'}'),
            Text(
                'Pickup: ${order['pickup_lat'] ?? 'N/A'}, ${order['pickup_lng'] ?? 'N/A'}'),
            Text(
                'Dropoff: ${order['dropoff_lat'] ?? 'N/A'}, ${order['dropoff_lng'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Notes: ${order['reason'] ?? 'N/A'}'),
          ],
        ),
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
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _infoCard('Online taxis', _stats['online_taxis']?.toString() ?? '0',
            Colors.green),
        _infoCard('Total taxis', _stats['total_taxis']?.toString() ?? '0',
            Colors.blue),
        _infoCard('Active orders', _stats['active_orders']?.toString() ?? '0',
            Colors.orange),
        _infoCard('Completed orders',
            _stats['completed_orders']?.toString() ?? '0', Colors.purple),
      ],
    );
  }

  Widget _buildTrendsCard() {
    final totalOrders = _stats['total_orders'] ?? 1;
    final activeOrders = _stats['active_orders'] ?? 0;
    final completedOrders = _stats['completed_orders'] ?? 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order distribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildProgressBar(
                'Active', activeOrders, totalOrders, Colors.orange),
            const SizedBox(height: 12),
            _buildProgressBar(
                'Completed', completedOrders, totalOrders, Colors.green),
            const SizedBox(height: 20),
            const Text('Driver activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTrendBars(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverStatusCard() {
    final totalDrivers =
        int.tryParse(_stats['total_drivers']?.toString() ?? '0') ?? 0;
    final onlineDrivers =
        int.tryParse(_stats['online_taxis']?.toString() ?? '0') ?? 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Total drivers: $totalDrivers'),
            Text('Drivers online: $onlineDrivers'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalDrivers > 0 ? onlineDrivers / totalDrivers : 0,
              color: Colors.green,
              backgroundColor: Colors.grey[300],
              minHeight: 10,
            ),
          ],
        ),
      ),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert #${emergency['id'] ?? 'N/A'}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Driver: ${emergency['driver_name'] ?? 'N/A'}'),
            Text('Phone: ${emergency['phone'] ?? 'N/A'}'),
            Text(
                'Location: ${emergency['lat'] ?? 'N/A'}, ${emergency['lng'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Created at: ${emergency['created_at'] ?? 'N/A'}'),
          ],
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

class DrvierDetailSheet extends StatelessWidget {
  final Map<String, dynamic> driver;
  final void Function(bool toOnline) onStatusToggle;

  const DrvierDetailSheet({
    required this.driver,
    required this.onStatusToggle,
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
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
