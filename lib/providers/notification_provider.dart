import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATIONS PROVIDER  — single query, no duplicates
//
//  Why a single query is correct:
//
//  sendToAll() creates one notification doc per user, INCLUDING the sender.
//  So the admin already has a doc with userId == adminId for every broadcast.
//  Querying senderId == adminId and merging would surface one extra copy
//  per OTHER recipient — causing N duplicates for N users.
//
//  The sender sees their own broadcast via userId == senderId (their recipient doc).
//  No second query needed.
//
//  For direct messages (sendToUser) where the sender is NOT a recipient:
//  we add a second query limited only to docs where userId == senderId
//  (the sender's own outbox copy written by sendToUser when target == self).
//  Since sendToUser only creates ONE doc, there is no duplication risk.
// ─────────────────────────────────────────────────────────────────────────────
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
    data: (user) {
      if (user == null) return const Stream.empty();

      final db = FirebaseFirestore.instance;

      if (user.role == UserRole.superAdmin) {
        return db
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .map(
              (snap) => snap.docs.map(NotificationModel.fromFirestore).toList(),
            );
      }

      return db
          .collection('notifications')
          .where('userId', isEqualTo: user.id)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map(NotificationModel.fromFirestore).toList(),
          );
    },
  );
});

/// Unread badge count — received messages only
final unreadmessageCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
