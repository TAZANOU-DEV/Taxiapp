import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      channelDescription: 'Notifications for emergency alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details);
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
}
