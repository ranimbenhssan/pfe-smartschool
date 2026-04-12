import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Provider ────────────────────────────────────────────────────────────────
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ─── Background handler (must be top-level) ──────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
//  NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  static const _channelId = 'smartschool_channel';
  static const _channelName = 'SmartSchool Notifications';

  String? _currentUserId;

  // ─── Set current user (call after login) ─────────────────────────────────
  void setCurrentUser(String userId) {
    _currentUserId = userId;
    _registerFcmToken();
  }

  // ─── Initialize ──────────────────────────────────────────────────────────
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
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    // Create Android notification channel
    final plugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (plugin != null) {
      await plugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ),
      );
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveFcmTokenToFirestore);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // App opened from terminated state via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationOpen(initial);

    debugPrint('[FCM] NotificationService initialized.');
  }

  // ─── Register / Save FCM Token ───────────────────────────────────────────
  Future<void> _registerFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveFcmTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
    }
  }

  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      if (_currentUserId == null) return;
      debugPrint('[FCM] Saving token for user: $_currentUserId');
      await _db.collection('users').doc(_currentUserId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token saved to Firestore.');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  // ─── Foreground Message Handler ──────────────────────────────────────────
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

  // ─── Notification Tap Handlers ───────────────────────────────────────────
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[FCM] Opened from notification: ${message.data}');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped: ${response.payload}');
  }

  // ─── Send Notification (direct Firestore — no Cloud Functions) ───────────
  Future<bool> sendToUser(
    String userId,
    String title,
    String body, {
    String type = 'general',
    String senderId = '',
    String senderName = '',
    String senderRole = '',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': body,
        'type': type,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'attachments': attachments,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[FCM] Error sending notification: $e');
      return false;
    }
  }

  Future<bool> sendToRole(
    String role,
    String title,
    String body, {
    String type = 'general',
  }) async {
    try {
      final usersSnap =
          await _db.collection('users').where('role', isEqualTo: role).get();

      for (final userDoc in usersSnap.docs) {
        await _db.collection('notifications').add({
          'userId': userDoc.id,
          'title': title,
          'message': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('[FCM] Notification sent to role: $role');
      return true;
    } catch (e) {
      debugPrint('[FCM] Error sending to role: $e');
      return false;
    }
  }

  Future<bool> sendToClass(
    String classId,
    String title,
    String body, {
    String type = 'general',
  }) async {
    try {
      // Get all students in the class
      final studentsSnap =
          await _db
              .collection('students')
              .where('classId', isEqualTo: classId)
              .get();

      for (final studentDoc in studentsSnap.docs) {
        final userId = studentDoc.data()['userId'] as String?;
        if (userId == null || userId.isEmpty) continue;
        await _db.collection('notifications').add({
          'userId': userId,
          'title': title,
          'message': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('[FCM] Notification sent to class: $classId');
      return true;
    } catch (e) {
      debugPrint('[FCM] Error sending to class: $e');
      return false;
    }
  }

  Future<bool> sendToAll(
    String title,
    String body, {
    String type = 'general',
  }) async {
    try {
      final usersSnap = await _db.collection('users').get();
      for (final userDoc in usersSnap.docs) {
        await _db.collection('notifications').add({
          'userId': userDoc.id,
          'title': title,
          'message': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('[FCM] Notification sent to all users');
      return true;
    } catch (e) {
      debugPrint('[FCM] Error sending to all: $e');
      return false;
    }
  }

  // ─── Resolve AI Flag (direct Firestore) ──────────────────────────────────
  Future<bool> resolveAiFlag(String flagId, {String? note}) async {
    try {
      await _db.collection('ai_flags').doc(flagId).update({
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'note': note ?? '',
      });
      debugPrint('[FCM] AI flag resolved: $flagId');
      return true;
    } catch (e) {
      debugPrint('[FCM] Error resolving flag: $e');
      return false;
    }
  }

  // ─── Mark notification read ───────────────────────────────────────────────
  Future<void> markRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('[FCM] Error marking read: $e');
    }
  }

  // ─── Get FCM Token ────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
      return null;
    }
  }
}
