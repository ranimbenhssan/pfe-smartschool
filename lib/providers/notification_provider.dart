import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Always reads from 'notifications' collection ───
final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>(
        (ref, userId) {
  return FirebaseFirestore.instance
      .collection('notifications')  // ← MUST stay 'notifications'
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => NotificationModel.fromFirestore(d))
          .toList());
});
final unreadmessageCountProvider = Provider.family<int, String>((ref, userId) {
  return ref
      .watch(notificationsProvider(userId))
      .maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
