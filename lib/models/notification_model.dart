import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { announcement, form, note, course, report, general }

enum AttachmentType { image, pdf, document }

class AttachmentModel {
  final String url;
  final String name;
  final AttachmentType type;
  final int sizeBytes;

  const AttachmentModel({
    required this.url,
    required this.name,
    required this.type,
    required this.sizeBytes,
  });

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    return AttachmentModel(
      url: map['url']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: AttachmentType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AttachmentType.document,
      ),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'url': url,
    'name': name,
    'type': type.name,
    'sizeBytes': sizeBytes,
  };
}

class NotificationModel {
  final String id;
  final String userId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String title;
  final String message;
  final MessageType messageType;
  final String rawMessageType; // raw Firestore string e.g. 'attendance'
  final List<AttachmentModel> attachments;
  final String recipientLabel;
  final String originalRecipient;
  final String originalRecipientId;
  final String replyToId;
  final String replyToTitle;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.title,
    required this.message,
    required this.messageType,
    this.rawMessageType = '',
    required this.attachments,
    required this.recipientLabel,
    this.originalRecipient = '',
    this.originalRecipientId = '',
    this.replyToId = '',
    this.replyToTitle = '',
    required this.isRead,
    required this.createdAt,
  });

  bool get isReply => replyToId.isNotEmpty;

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;

    List<AttachmentModel> parseAttachments() {
      final list = raw['attachments'];
      if (list == null || list is! List) return [];
      return list
          .map(
            (a) => AttachmentModel.fromMap(Map<String, dynamic>.from(a as Map)),
          )
          .toList();
    }

    return NotificationModel(
      id: doc.id,
      userId: raw['userId']?.toString() ?? '',
      senderId: raw['senderId']?.toString() ?? '',
      senderName: raw['senderName']?.toString() ?? '',
      senderRole: raw['senderRole']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      message: raw['message']?.toString() ?? '',
      messageType: MessageType.values.firstWhere(
        (t) => t.name == raw['messageType'],
        orElse: () => MessageType.general,
      ),
      rawMessageType: raw['messageType']?.toString() ?? '',
      attachments: parseAttachments(),
      recipientLabel: raw['recipientLabel']?.toString() ?? '',
      originalRecipient: raw['originalRecipient']?.toString() ?? '',
      originalRecipientId: raw['originalRecipientId']?.toString() ?? '',
      replyToId: raw['replyToId']?.toString() ?? '',
      replyToTitle: raw['replyToTitle']?.toString() ?? '',
      isRead: raw['isRead'] as bool? ?? false,
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'senderId': senderId,
    'senderName': senderName,
    'senderRole': senderRole,
    'title': title,
    'message': message,
    'messageType': messageType.name,
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'recipientLabel': recipientLabel,
    'originalRecipient': originalRecipient,
    'originalRecipientId': originalRecipientId,
    'replyToId': replyToId,
    'replyToTitle': replyToTitle,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
