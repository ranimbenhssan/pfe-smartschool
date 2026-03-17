import 'package:cloud_firestore/cloud_firestore.dart';

enum FlagType { frequentAbsent, latePattern, suspicious }

class AiFlagModel {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final FlagType type;
  final String details;
  final double riskScore;
  final bool resolved;
  final DateTime detectedAt;
  final DateTime? resolvedAt;

  const AiFlagModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.type,
    required this.details,
    required this.riskScore,
    required this.resolved,
    required this.detectedAt,
    this.resolvedAt,
  });

  factory AiFlagModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AiFlagModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      classId: data['classId'] ?? '',
      type: _parseType(data['type']),
      details: data['details'] ?? '',
      riskScore: (data['riskScore'] ?? 0).toDouble(),
      resolved: data['resolved'] ?? false,
      detectedAt: (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'type': type.name,
      'details': details,
      'riskScore': riskScore,
      'resolved': resolved,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  static FlagType _parseType(String? type) {
    switch (type) {
      case 'frequentAbsent':
        return FlagType.frequentAbsent;
      case 'latePattern':
        return FlagType.latePattern;
      case 'suspicious':
        return FlagType.suspicious;
      default:
        return FlagType.suspicious;
    }
  }

  String get typeLabel {
    switch (type) {
      case FlagType.frequentAbsent:
        return 'Frequent Absence';
      case FlagType.latePattern:
        return 'Late Pattern';
      case FlagType.suspicious:
        return 'Suspicious Behavior';
    }
  }

  AiFlagModel copyWith({bool? resolved, DateTime? resolvedAt}) {
    return AiFlagModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      type: type,
      details: details,
      riskScore: riskScore,
      resolved: resolved ?? this.resolved,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  String toString() =>
      'AiFlagModel(studentId: $studentId, type: ${type.name}, resolved: $resolved)';
}