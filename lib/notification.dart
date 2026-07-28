import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'emergency', 'message', 'update'
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

/// Global key for showing overlay dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final List<NotificationItem> _notificationHistory = [];

  /// Callback for when a new notification arrives (used by HomePage for overlay)
  static void Function(NotificationItem)? onNewNotification;

  static Future<void> initialize() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      // Note: plugin v22+ uses named parameter `settings`
      await _notificationsPlugin.initialize(settings: settings);
    } catch (_) {
      // Fallback: notifications not available on this platform
    }
  }

  static List<NotificationItem> getNotificationHistory() {
    return _notificationHistory;
  }

  static List<NotificationItem> getUnreadNotifications() {
    return _notificationHistory.where((n) => !n.isRead).toList();
  }

  static void markAsRead(String notificationId) {
    for (var notification in _notificationHistory) {
      if (notification.id == notificationId) {
        notification.isRead = true;
        break;
      }
    }
  }

  static void clearNotifications() {
    _notificationHistory.clear();
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String type,
    int id = 0,
  }) async {
    final notificationItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
    );

    _notificationHistory.insert(0, notificationItem);

    // Fire callback for UI overlay
    if (onNewNotification != null) {
      onNewNotification!(notificationItem);
    }

    // Show system notification if possible
    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'taxi_emergency_channel',
            'Taxi Emergency Notifications',
            channelDescription: 'Emergency alerts and notifications',
            importance: type == 'emergency'
                ? Importance.high
                : Importance.defaultImportance,
            priority:
                type == 'emergency' ? Priority.high : Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      debugPrint('Notify(id=$id): $title - $body');
    }

    // Save to backend
    await _saveNotificationToBackend(notificationItem);
  }

  /// Shows an in-app overlay dialog for emergency notifications
  static void showEmergencyOverlay({
    required String title,
    required String body,
    String? taxiId,
    String? driverName,
    String? email,
    String? phone,
    String? taxiMatricule,
    String? pictureUrl,
  }) {
    // Use the global navigator key to show dialog from anywhere
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('No context available for overlay');
      return;
    }

    // Play a sound/vibration pattern (best effort)
    try {
      _notificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'taxi_emergency_channel',
            'Taxi Emergency Notifications',
            channelDescription: 'Emergency alerts and notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([500, 500, 500, 500, 1000]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {
      // ignore
    }

    // Show in-app emergency alert dialog (only from main thread)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext == null) return;
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.red.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.yellow, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.yellow,
                    child: (pictureUrl != null && pictureUrl.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              pictureUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                          )
                        : Text(
                            (driverName ?? 'U')
                                .toString()
                                .split(' ')
                                .map((s) => s.isNotEmpty ? s[0] : '')
                                .take(2)
                                .join(),
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 20),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (driverName != null)
                          Text(
                            'Driver: $driverName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        if (taxiId != null)
                          Text(
                            'Taxi ID: $taxiId',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        if (email != null && email.isNotEmpty)
                          Text(
                            'Email: $email',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        if (phone != null && phone.isNotEmpty)
                          Text(
                            'Phone: $phone',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        if (taxiMatricule != null && taxiMatricule.isNotEmpty)
                          Text(
                            'Matricule: $taxiMatricule',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'ACKNOWLEDGE',
                style: TextStyle(
                    color: Colors.yellow, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    });
  }

  static Future<void> showIncomingAlert(String message) async {
    await showNotification(
      title: 'Emergency Alert!',
      body: message,
      type: 'emergency',
    );
  }

  static Future<void> showMessage(String from, String message) async {
    await showNotification(
      title: 'New Message from $from',
      body: message,
      type: 'message',
      id: 1,
    );
  }

  static Future<void> showUpdate(String update) async {
    await showNotification(
      title: 'Update',
      body: update,
      type: 'update',
      id: 2,
    );
  }

  static Future<void> _saveNotificationToBackend(
      NotificationItem notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userData = prefs.getString('user');

      if (token == null || userData == null) {
        debugPrint('No auth token or user data found, skipping backend save');
        return;
      }

      final user = jsonDecode(userData);
      final taxiId = user['email'];

      const baseUrl = 'https://taxiapp-back.vercel.app';

      final response = await http.post(
        Uri.parse('$baseUrl/api/activities'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'taxiId': taxiId,
          'title': notification.title,
          'description': notification.body,
          'type': notification.type,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Notification saved to backend successfully');
      } else {
        debugPrint(
            'Failed to save notification to backend: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error saving notification to backend: $e');
    }
  }
}
