import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { attendance, aiAlert, general, rfid }

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final String? relatedId;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.relatedId,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _parseType(data['type']),
      isRead: data['isRead'] ?? false,
      relatedId: data['relatedId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.name,
      'isRead': isRead,
      'relatedId': relatedId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'attendance':
        return NotificationType.attendance;
      case 'aiAlert':
        return NotificationType.aiAlert;
      case 'rfid':
        return NotificationType.rfid;
      default:
        return NotificationType.general;
    }
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'NotificationModel(id: $id, title: $title, isRead: $isRead)';
}