import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Notifications Stream ───
final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getNotifications(userId);
});

// ─── Unread Count ───
final unreadNotificationsCountProvider =
    Provider.family<int, String>((ref, userId) {
  return ref.watch(notificationsProvider(userId)).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});