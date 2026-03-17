import 'package:cloud_firestore/cloud_firestore.dart';

enum RfidDirection { in_, out }

class RfidLogModel {
  final String id;
  final String rfidTag;
  final String studentId;
  final String studentName;
  final String doorId;
  final RfidDirection direction;
  final DateTime timestamp;
  final bool isRecognized;

  const RfidLogModel({
    required this.id,
    required this.rfidTag,
    required this.studentId,
    required this.studentName,
    required this.doorId,
    required this.direction,
    required this.timestamp,
    required this.isRecognized,
  });

  factory RfidLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RfidLogModel(
      id: doc.id,
      rfidTag: data['rfidTag'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      doorId: data['doorId'] ?? '',
      direction: data['direction'] == 'IN' ? RfidDirection.in_ : RfidDirection.out,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRecognized: data['isRecognized'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'rfidTag': rfidTag,
      'studentId': studentId,
      'studentName': studentName,
      'doorId': doorId,
      'direction': direction == RfidDirection.in_ ? 'IN' : 'OUT',
      'timestamp': Timestamp.fromDate(timestamp),
      'isRecognized': isRecognized,
    };
  }

  @override
  String toString() =>
      'RfidLogModel(rfidTag: $rfidTag, direction: ${direction.name}, timestamp: $timestamp)';
}