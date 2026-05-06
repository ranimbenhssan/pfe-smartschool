import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATIONS PROVIDER
//
//  Shows:
//  1. Messages RECEIVED by this user  (userId == currentUser.id)
//  2. Messages SENT by this user      — ONE representative per send operation
//                                       (the doc where userId == senderId,
//                                        i.e. the sender's own copy)
//
//  The old merge-streams approach showed one copy PER RECIPIENT, so a
//  "whole school" broadcast to 4 users appeared 4 times in the sender's inbox.
//
//  Fix: for sent messages, only include docs where userId == senderId
//  (the admin's own copy). These are deduped by Firestore doc id.
//  Received docs (userId != senderId) are shown normally.
// ─────────────────────────────────────────────────────────────────────────────
final notificationsProvider = StreamProvider.family<
  List<NotificationModel>,
  String
>((ref, userId) {
  if (userId.isEmpty) return Stream.value([]);

  final db = FirebaseFirestore.instance;

  // Stream 1: messages where this user is the recipient
  // (includes broadcasts sent to them, and their own copy of broadcasts they sent)
  final receivedStream = db
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());

  // Stream 2: messages this user SENT to OTHERS
  // Filter: senderId == userId AND userId != userId (i.e. sent to someone else)
  // Firestore can't do !=, so we query senderId == userId and filter client-side
  // to exclude docs already in stream 1 (where userId == senderId == currentUser).
  // This gives us the "outbox" view of messages sent to other people.
  final sentStream = db
      .collection('notifications')
      .where('senderId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) =>
            s.docs
                .map(NotificationModel.fromFirestore)
                .where(
                  (m) => m.userId != userId,
                ) // exclude self-copies (already in stream 1)
                .toList(),
      );

  return _mergeDeduped(receivedStream, sentStream, userId);
});

// ─────────────────────────────────────────────────────────────────────────────
//  MERGE + DEDUP
//
//  Combines received + sent streams.
//  For sent messages (userId != senderId's userId), shows only ONE entry
//  per unique (senderId + title + ~timestamp) group — the first doc found.
//  This means a broadcast to 100 students shows once, not 100 times.
// ─────────────────────────────────────────────────────────────────────────────
Stream<List<NotificationModel>> _mergeDeduped(
  Stream<List<NotificationModel>> received,
  Stream<List<NotificationModel>> sent,
  String currentUserId,
) async* {
  var listA = <NotificationModel>[];
  var listB = <NotificationModel>[];

  late StreamController<List<NotificationModel>> ctrl;
  StreamSubscription? subA, subB;

  List<NotificationModel> build() {
    // All received docs (userId == currentUser) — show as-is
    final receivedDocs = listA;

    // Sent docs (userId != currentUser, senderId == currentUser)
    // Deduplicate: for each unique broadcast, show only one entry.
    // Group key: title + createdAt rounded to nearest 10 seconds
    final seenGroupKeys = <String>{};
    final sentDeduplicated = <NotificationModel>[];
    for (final m in listB) {
      final ts = (m.createdAt.millisecondsSinceEpoch ~/ 10000).toString();
      final key = '${m.title}__${m.senderId}__$ts';
      if (seenGroupKeys.add(key)) {
        // Show this as a "Sent" entry — modify recipientLabel to indicate it's outgoing
        sentDeduplicated.add(m);
      }
    }

    // Merge: combine received + deduplicated sent, sort by date, dedup by id
    final seen = <String>{};
    final merged = <NotificationModel>[];
    for (final m in [...receivedDocs, ...sentDeduplicated]) {
      if (seen.add(m.id)) merged.add(m);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  ctrl = StreamController<List<NotificationModel>>(
    onListen: () {
      subA = received.listen((l) {
        listA = l;
        if (!ctrl.isClosed) ctrl.add(build());
      }, onError: ctrl.addError);
      subB = sent.listen((l) {
        listB = l;
        if (!ctrl.isClosed) ctrl.add(build());
      }, onError: ctrl.addError);
    },
    onCancel: () {
      subA?.cancel();
      subB?.cancel();
    },
  );

  yield* ctrl.stream;
}

/// Unread count — only count received messages (not sent copies)
final unreadmessageCountProvider = Provider.family<int, String>((ref, userId) {
  return ref
      .watch(notificationsProvider(userId))
      .maybeWhen(
        data:
            (list) => list.where((n) => !n.isRead && n.userId == userId).length,
        orElse: () => 0,
      );
});
