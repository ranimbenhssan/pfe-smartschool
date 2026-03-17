import 'package:cloud_firestore/cloud_firestore.dart';

enum ComfortLevel { good, average, bad }

class SensorModel {
  final String id;
  final String roomId;
  final String roomName;
  final double temperature;
  final double humidity;
  final double lightLevel;
  final double noiseLevel;
  final DateTime timestamp;

  const SensorModel({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.temperature,
    required this.humidity,
    required this.lightLevel,
    required this.noiseLevel,
    required this.timestamp,
  });

  factory SensorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SensorModel(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      roomName: data['roomName'] ?? '',
      temperature: (data['temperature'] ?? 0).toDouble(),
      humidity: (data['humidity'] ?? 0).toDouble(),
      lightLevel: (data['lightLevel'] ?? 0).toDouble(),
      noiseLevel: (data['noiseLevel'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'temperature': temperature,
      'humidity': humidity,
      'lightLevel': lightLevel,
      'noiseLevel': noiseLevel,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // ─── Comfort Score (0-100) ───
  double get comfortScore {
    double score = 100;

    // Temperature: ideal 20-25°C
    if (temperature < 18 || temperature > 28) score -= 30;
    else if (temperature < 20 || temperature > 25) score -= 10;

    // Humidity: ideal 40-60%
    if (humidity < 30 || humidity > 70) score -= 25;
    else if (humidity < 40 || humidity > 60) score -= 10;

    // Light: ideal above 300 lux
    if (lightLevel < 100) score -= 25;
    else if (lightLevel < 300) score -= 10;

    // Noise: ideal below 50dB
    if (noiseLevel > 80) score -= 20;
    else if (noiseLevel > 60) score -= 10;

    return score.clamp(0, 100);
  }

  ComfortLevel get comfortLevel {
    final score = comfortScore;
    if (score >= 70) return ComfortLevel.good;
    if (score >= 40) return ComfortLevel.average;
    return ComfortLevel.bad;
  }

  String get comfortRecommendation {
    final List<String> tips = [];
    if (temperature > 25) tips.add('Room is too hot — open windows or turn on AC');
    if (temperature < 20) tips.add('Room is too cold — consider heating');
    if (humidity > 60) tips.add('High humidity — improve ventilation');
    if (humidity < 40) tips.add('Low humidity — consider a humidifier');
    if (lightLevel < 300) tips.add('Poor lighting — turn on more lights');
    if (noiseLevel > 60) tips.add('High noise level — ask for quiet');
    if (tips.isEmpty) return 'Classroom environment is comfortable';
    return tips.join(' • ');
  }

  @override
  String toString() =>
      'SensorModel(roomId: $roomId, temp: $temperature, humidity: $humidity)';
}