import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../notification.dart';

class SocketService {
  late IO.Socket socket;
  Function(Map<String, dynamic>)? onTaxiLocationUpdate;
  Function(Map<String, dynamic>)? onIncomingOrder;
  Function(Map<String, dynamic>)? onOrderStatusUpdate;
  Function(Map<String, dynamic>)? onEmergencyAlert;
  Function(Map<String, dynamic>)? onHelpOnWayUpdate;
  Function(String)? onTaxiOffline;

  void connect() {
    final serverUrl = kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    // Connection successful
    socket.on('connect', (_) {
      debugPrint('Connected to Socket.io server');
      NotificationService.showNotification(
        title: 'Connected',
        body: 'Successfully connected to server',
        type: 'update',
      );
    });

    // Real-time taxi location updates
    socket.on('taxi_location_updated', (data) {
      debugPrint('Taxi location update: $data');
      if (onTaxiLocationUpdate != null) {
        onTaxiLocationUpdate!(data);
      }
      NotificationService.showNotification(
        title: 'Taxi Location Update',
        body: 'Taxi ${data['taxiId']} location updated',
        type: 'update',
      );
    });

    // Incoming order notification
    socket.on('incoming_order', (data) {
      debugPrint('Incoming order: $data');
      if (onIncomingOrder != null) {
        onIncomingOrder!(data);
      }
      NotificationService.showNotification(
        title: 'Incoming Order Request',
        body:
            'Taxi ${data['fromTaxiId']} needs ${data['reason']} - ${data['lat']}, ${data['lng']}',
        type: 'message',
      );
    });

    // Order status updates
    socket.on('order_status_updated', (data) {
      debugPrint('Order status: $data');
      if (onOrderStatusUpdate != null) {
        onOrderStatusUpdate!(data);
      }
      final statusText = data['status'] == 'on_way'
          ? 'Taxi is on the way'
          : data['status'] == 'arrived'
              ? 'Taxi has arrived'
              : data['status'];
      NotificationService.showNotification(
        title: 'Order Update',
        body: '$statusText',
        type: 'update',
      );
    });

    // Taxi offline notification
    socket.on('taxi_offline', (data) {
      debugPrint('Taxi offline: ${data['taxiId']}');
      if (onTaxiOffline != null) {
        onTaxiOffline!(data['taxiId']);
      }
      NotificationService.showNotification(
        title: 'Taxi Offline',
        body: 'Taxi ${data['taxiId']} is now offline',
        type: 'update',
      );
    });

    // Listen for emergency alerts
    socket.on('emergencyAlert', (data) {
      debugPrint('Received alert: $data');
      if (onEmergencyAlert != null) {
        onEmergencyAlert!(Map<String, dynamic>.from(data));
      }
      final taxiNumber = data['taxiNumber'] ?? data['taxiId'];
      final driverName = data['driverName'] ?? 'Unknown';
      final alertMessage =
          'Emergency from Taxi $taxiNumber ($driverName): ${data['message']}';
      NotificationService.showNotification(
        title: '🚨 Emergency Alert',
        body: alertMessage,
        type: 'emergency',
      );
    });

    // Listen for helpers on the way
    socket.on('help_on_way', (data) {
      debugPrint('Help on way: $data');
      if (onHelpOnWayUpdate != null) {
        onHelpOnWayUpdate!(Map<String, dynamic>.from(data));
      }
      final helperTaxiId = data['helperTaxiId'] as String? ?? 'A taxi';
      NotificationService.showNotification(
        title: 'Help Update',
        body: 'Taxi $helperTaxiId is on the way',
        type: 'update',
      );
    });

    // Listen for location updates
    socket.on('locationUpdate', (data) {
      debugPrint('Location update: $data');
      NotificationService.showNotification(
        title: 'Location Update',
        body: 'Location has been updated',
        type: 'update',
      );
    });
  }

  void registerTaxi(String taxiId, double lat, double lng) {
    socket.emit('register_taxi', {
      'taxiId': taxiId,
      'lat': lat,
      'lng': lng,
    });
    NotificationService.showNotification(
      title: 'Taxi Registered',
      body: 'Taxi $taxiId registered in the system',
      type: 'update',
    );
  }

  void broadcastLocationUpdate(String taxiId, double lat, double lng) {
    socket.emit('location_update', {
      'taxiId': taxiId,
      'lat': lat,
      'lng': lng,
    });
  }

  void requestTaxi(String fromTaxiId, String toTaxiId, double lat, double lng,
      {String reason = 'assistance'}) {
    socket.emit('request_taxi', {
      'fromTaxiId': fromTaxiId,
      'toTaxiId': toTaxiId,
      'lat': lat,
      'lng': lng,
      'reason': reason,
    });
  }

  void acceptOrder(String orderId, String taxiId, String fromTaxiId) {
    socket.emit('accept_order', {
      'orderId': orderId,
      'taxiId': taxiId,
      'fromTaxiId': fromTaxiId,
    });
  }

  void updateOrderStatus(
      String orderId, String status, String taxiId, double lat, double lng) {
    socket.emit('order_status', {
      'orderId': orderId,
      'status': status,
      'taxiId': taxiId,
      'lat': lat,
      'lng': lng,
    });
  }

  void sendEmergency(String taxiId) {
    socket.emit('emergency', {'taxiId': taxiId, 'message': 'Help!'});
    // Record the activity
    NotificationService.showNotification(
      title: 'Emergency Alert Sent',
      body: 'Your emergency alert has been sent to nearby drivers',
      type: 'emergency',
    );
  }

  void sendHelpOnWay(
      String requestingTaxiId, String helperTaxiId, double lat, double lng) {
    socket.emit('help_on_way', {
      'requestingTaxiId': requestingTaxiId,
      'helperTaxiId': helperTaxiId,
      'lat': lat,
      'lng': lng,
      'message': 'Help is on the way',
    });
    NotificationService.showNotification(
      title: 'Help Sent',
      body: 'You notified the requester that help is on the way.',
      type: 'update',
    );
  }

  void sendLocation(String taxiId, double lat, double lng) {
    socket.emit('shareLocation', {
      'taxiId': taxiId,
      'lat': lat,
      'lng': lng,
    });
    // Record the activity
    NotificationService.showNotification(
      title: 'Location Shared',
      body: 'Your location has been shared with nearby drivers',
      type: 'update',
    );
  }
}
