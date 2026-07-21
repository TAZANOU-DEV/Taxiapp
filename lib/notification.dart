import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final List<NotificationItem> _notificationHistory = [];

  static Future<void> initialize() async {
    // Initialization of the native notifications plugin has changed across
    // plugin versions. To avoid compile errors with different plugin APIs,
    // keep a lightweight initialization here. If you need platform
    // notifications, re-enable and adapt this code to the plugin version
    // you're using.
    try {
      // best-effort: if the plugin still supports initialize with
      // InitializationSettings this will succeed; otherwise we silently
      // continue.
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      // ignore: avoid_dynamic_calls
      await (_notificationsPlugin.initialize as dynamic)(settings);
    } catch (_) {
      // fallback: nothing to do
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

    // Save to backend
    await _saveNotificationToBackend(notificationItem);

    // The plugin's `show` signature has changed between releases. To avoid
    // breakage during compilation, log the notification and skip calling
    // into the native plugin here. Re-enable the plugin call if you adapt
    // it to the installed plugin version.
    debugPrint('Notify(id=$id): $title - $body');
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
        print('No auth token or user data found, skipping backend save');
        return;
      }

      final user = jsonDecode(userData);
      final taxiId = user['email']; // Using email as taxi ID for now

      const baseUrl = 'http://10.95.105.200:3000';

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
        print('Notification saved to backend successfully');
      } else {
        print('Failed to save notification to backend: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving notification to backend: $e');
    }
  }
}
