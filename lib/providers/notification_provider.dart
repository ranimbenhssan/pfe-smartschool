import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── Returns received + sent messages merged into one sorted list ─────────────
final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
      if (userId.isEmpty) return Stream.value([]);

      final db = FirebaseFirestore.instance;

      final receivedStream = db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());

      final sentStream = db
          .collection('notifications')
          .where('senderId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());

      return _mergeStreams(receivedStream, sentStream);
    });

Stream<List<NotificationModel>> _mergeStreams(
  Stream<List<NotificationModel>> a,
  Stream<List<NotificationModel>> b,
) async* {
  var listA = <NotificationModel>[];
  var listB = <NotificationModel>[];

  late StreamController<List<NotificationModel>> ctrl;
  StreamSubscription? subA, subB;

  ctrl = StreamController<List<NotificationModel>>(
    onListen: () {
      void emit() {
        if (ctrl.isClosed) return;
        final seen = <String>{};
        final merged =
            [...listA, ...listB].where((m) => seen.add(m.id)).toList()
              ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
        ctrl.add(merged);
      }

      subA = a.listen((l) {
        listA = l;
        emit();
      }, onError: ctrl.addError);
      subB = b.listen((l) {
        listB = l;
        emit();
      }, onError: ctrl.addError);
    },
    onCancel: () {
      subA?.cancel();
      subB?.cancel();
    },
  );

  yield* ctrl.stream;
}

/// Unread count — only counts messages received by this user
final unreadmessageCountProvider = Provider.family<int, String>((ref, userId) {
  return ref
      .watch(notificationsProvider(userId))
      .maybeWhen(
        data:
            (list) => list.where((n) => !n.isRead && n.userId == userId).length,
        orElse: () => 0,
      );
});
