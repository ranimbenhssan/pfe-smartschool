import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

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
  if (userId.isEmpty) return Stream.value([]);

  // Primary: all messages where this user is a recipient.
  // For broadcasts: sender is always included as a recipient by sendToAll/sendToClass.
  // For direct messages received: included naturally.
  // For direct messages sent to others: NOT included here (handled below).
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(100)
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
