import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Provider ───
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ─── Background handler (must be top-level) ───
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  static const _channelId = 'smartschool_channel';
  static const _channelName = 'SmartSchool message';

  String? _currentUserId;

  void setCurrentUser(String userId) {
    _currentUserId = userId;
    _registerFcmToken();
  }

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // ─── Create Android notification channel ───
    // REPLACE the plugin block with:
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

    _messaging.onTokenRefresh.listen(_saveFcmTokenToFirestore);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationOpen(initial);

    debugPrint('[FCM] NotificationService initialized.');
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveFcmTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      if (_currentUserId == null) return;
      await _db.collection('users').doc(_currentUserId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

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

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[FCM] Opened: ${message.data}');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Tapped: ${response.payload}');
  }

  // ─── Send to single user ───
  Future<bool> sendToUser(
    String userId,
    String title,
    String body, {
    String type = 'general',
    String senderId = '',
    String senderName = '',
    String senderRole = '',
    List<Map<String, dynamic>> attachments = const [],
    String recipientLabel = '',
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': body,
        'messageType': type,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'attachments': attachments,
        'recipientLabel': recipientLabel,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[FCM] Error: $e');
      return false;
    }
  }

  // ─── Send to all users ───
  Future<bool> sendToAll(
    String title,
    String body, {
    String type = 'general',
    String senderId = '',
    String senderName = '',
    String senderRole = '',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      final usersSnap = await _db.collection('users').get();
      for (final userDoc in usersSnap.docs) {
        await _db.collection('notifications').add({
          'userId': userDoc.id,
          'title': title,
          'message': body,
          'messageType': type,
          'senderId': senderId, // ← was missing
          'senderName': senderName, // ← was missing
          'senderRole': senderRole, // ← was missing
          'attachments': attachments, // ← was missing
          'recipientLabel': 'Whole School',
          'replyToId': '',
          'replyToTitle': '',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('[FCM] sendToAll error: $e');
      return false;
    }
  }

  // ─── Send to class ───
  Future<bool> sendToClass(
    String classId,
    String title,
    String body, {
    String type = 'general',
    String senderId = '',
    String senderName = '',
    String senderRole = '',
    List<Map<String, dynamic>> attachments = const [], // ← was missing
    String className = '',
  }) async {
    try {
      final studentsSnap =
          await _db
              .collection('students')
              .where('classId', isEqualTo: classId)
              .get();
      for (final studentDoc in studentsSnap.docs) {
        final userId = studentDoc.data()['userId'] as String? ?? '';
        if (userId.isEmpty) continue;
        await _db.collection('notifications').add({
          'userId': userId,
          'title': title,
          'message': body,
          'messageType': type,
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'attachments': attachments, // ← was missing
          'recipientLabel': className.isNotEmpty ? 'Class $className' : 'Class',
          'replyToId': '',
          'replyToTitle': '',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('[FCM] sendToClass error: $e');
      return false;
    }
  }

  // ─── Send to role ───
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
          'messageType': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('[FCM] Error: $e');
      return false;
    }
  }

  // ─── Mark read ───
  Future<void> markRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('[FCM] Error: $e');
    }
  }

  // ─── Resolve AI flag ───
  Future<bool> resolveAiFlag(String flagId, {String? note}) async {
    try {
      await _db.collection('ai_flags').doc(flagId).update({
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'note': note ?? '',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }
}
