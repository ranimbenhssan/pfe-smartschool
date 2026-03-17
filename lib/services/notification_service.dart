import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ─── Initialize ───
  Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });
  }

  // ─── Get FCM Token ───
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // ─── Show Local Notification ───
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'smartschool_channel',
      'SmartSchool Notifications',
      channelDescription: 'Notifications from SmartSchool app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'SmartSchool',
      message.notification?.body ?? '',
      notificationDetails,
    );
  }
}
