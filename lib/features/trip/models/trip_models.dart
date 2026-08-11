import 'package:latlong2/latlong.dart';

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.tripCode,
  });

  final int id;
  final String name;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? tripCode;

  bool get isOngoing => endedAt == null;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: _intValue(json["id"]),
      name: _stringValue(json["name"], fallback: "Trip"),
      startedAt: _dateValue(json["startedAt"]),
      endedAt: _dateValue(json["endedAt"]),
      tripCode: _nullableString(json["tripCode"]),
    );
  }
}

class TripSummary {
  const TripSummary({
    required this.userId,
    required this.totalPoints,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.topSpeed,
    required this.averageSpeed,
    required this.durationSeconds,
    required this.points,
  });

  final int userId;
  final int totalPoints;
  final DateTime? startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double topSpeed;
  final double averageSpeed;
  final int durationSeconds;
  final List<TripPoint> points;

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    final pointsJson = json["points"];

    return TripSummary(
      userId: _intValue(json["userId"]),
      totalPoints: _intValue(json["totalPoints"]),
      startTime: _dateValue(json["startTime"]),
      endTime: _dateValue(json["endTime"]),
      distanceKm: _doubleValue(json["distanceKm"]),
      topSpeed: _doubleValue(json["topSpeed"]),
      averageSpeed: _doubleValue(json["averageSpeed"]),
      durationSeconds: _intValue(json["durationSeconds"]),
      points: pointsJson is List<dynamic>
          ? pointsJson
                .whereType<Map<String, dynamic>>()
                .map(TripPoint.fromJson)
                .toList()
          : const [],
    );
  }
}

class TripPoint {
  const TripPoint({
    required this.position,
    required this.speedKmh,
    required this.heading,
    required this.accuracy,
    required this.recordedAt,
  });

  final LatLng position;
  final double speedKmh;
  final double heading;
  final double accuracy;
  final DateTime? recordedAt;

  factory TripPoint.fromJson(Map<String, dynamic> json) {
    return TripPoint(
      position: LatLng(
        _doubleValue(json["latitude"]),
        _doubleValue(json["longitude"]),
      ),
      speedKmh: _doubleValue(json["speed"]),
      heading: _doubleValue(json["heading"]),
      accuracy: _doubleValue(json["accuracy"]),
      recordedAt: _dateValue(json["recordedAt"]),
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;

  return 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;

  return 0;
}

String _stringValue(dynamic value, {required String fallback}) {
  if (value is String && value.isNotEmpty) return value;

  return fallback;
}

String? _nullableString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;

  return null;
}

DateTime? _dateValue(dynamic value) {
  if (value is! String || value.isEmpty) return null;

  return DateTime.tryParse(value);
}
