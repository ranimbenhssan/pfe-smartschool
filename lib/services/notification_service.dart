import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─── Background message handler (top-level function required by FCM) ─────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();


  static const _channelId = 'smartschool_channel';
  static const _channelName = 'SmartSchool Notifications';

  // ─── Initialize ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Init local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ));

    // Store FCM token in Firestore via Cloud Function
    await _registerFcmToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveFcmToken);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a terminated state via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationOpen(initial);

    debugPrint('[FCM] NotificationService initialized.');
  }

  // ─── Register / Save Token ─────────────────────────────────────────────────

  Future<void> _registerFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveFcmToken(token);
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      debugPrint('[FCM] Saving token: ${token.substring(0, 20)}...');
      final callable = _functions.httpsCallable('storeFcmToken');
      await callable.call({'token': token});
      debugPrint('[FCM] Token saved to Firestore.');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  // ─── Foreground Message Handler ────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  // ─── Notification Tap Handler ──────────────────────────────────────────────

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[FCM] Opened from notification: ${message.data}');
    // Navigation based on notification type handled in main app
    // via notificationTypeProvider
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped: ${response.payload}');
  }

  // ─── Send Notification (callable from Flutter UI) ──────────────────────────

  Future<bool> sendToUser(String userId, String title, String body) async {
    return _send('user', userId, title, body);
  }

  Future<bool> sendToRole(String role, String title, String body) async {
    return _send('role', role, title, body);
  }

  Future<bool> sendToClass(String classId, String title, String body) async {
    return _send('class', classId, title, body);
  }

  Future<bool> _send(String targetType, String targetId, String title, String body) async {
    try {
      final callable = _functions.httpsCallable('sendNotification');
      final result = await callable.call({
        'targetType': targetType,
        'targetId': targetId,
        'title': title,
        'body': body,
      });
      return result.data['success'] == true;
    } catch (e) {
      debugPrint('[FCM] Error sending notification: $e');
      return false;
    }
  }

  // ─── Resolve AI Flag (callable) ────────────────────────────────────────────

  Future<bool> resolveAiFlag(String flagId, {String? note}) async {
    try {
      final callable = _functions.httpsCallable('resolveAiFlag');
      final result = await callable.call({'flagId': flagId, 'note': note ?? ''});
      return result.data['success'] == true;
    } catch (e) {
      debugPrint('[FCM] Error resolving flag: $e');
      return false;
    }
  }
}