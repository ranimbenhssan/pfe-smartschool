import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String name;
  final int floor;
  final int capacity;
  final double comfortScore;
  final DateTime? lastUpdated;

  const RoomModel({
    required this.id,
    required this.name,
    required this.floor,
    required this.capacity,
    required this.comfortScore,
    this.lastUpdated,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      id: doc.id,
      name: data['name'] ?? '',
      floor: data['floor'] ?? 0,
      capacity: data['capacity'] ?? 30,
      comfortScore: (data['comfortScore'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'floor': floor,
      'capacity': capacity,
      'comfortScore': comfortScore,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : null,
    };
  }

  RoomModel copyWith({
    String? name,
    int? floor,
    int? capacity,
    double? comfortScore,
    DateTime? lastUpdated,
  }) {
    return RoomModel(
      id: id,
      name: name ?? this.name,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      comfortScore: comfortScore ?? this.comfortScore,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() =>
      'RoomModel(id: $id, name: $name, floor: $floor)';
}