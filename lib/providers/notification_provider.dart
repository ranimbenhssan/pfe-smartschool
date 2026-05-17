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
final notificationsProvider = StreamProvider.family<
  List<NotificationModel>,
  String
>((ref, userId) {
  final currentUser = ref.watch(currentUserProvider).value;
  final isSuperAdmin = currentUser?.role == UserRole.superAdmin;

  if (isSuperAdmin) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) {
          final all = snap.docs.map(NotificationModel.fromFirestore).toList();
          return all.where((n) {
            final t =
                n.rawMessageType.isNotEmpty
                    ? n.rawMessageType
                    : n.messageType.name;
            // Hide attendance corrections
            if (t == 'attendance') return false;
            // Hide student personal absence flag — keep only admin copy
            if (t == 'absence_flag' && n.recipientLabel != 'Admin')
              return false;
            // Hide password_reset from teachers/students
            if (t == 'password_reset' &&
                (n.senderRole == 'teacher' || n.senderRole == 'student')) {
              return false;
            }
            return true;
          }).toList();
        });
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(NotificationModel.fromFirestore).toList());
});

/// Unread badge count — received messages only
final unreadmessageCountProvider = Provider.family<int, String>((ref, userId) {
  return ref
      .watch(notificationsProvider(userId))
      .maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
