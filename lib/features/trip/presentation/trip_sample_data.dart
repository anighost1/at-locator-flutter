import 'package:latlong2/latlong.dart';

class TripSummary {
  const TripSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startedAt,
    required this.duration,
    required this.points,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime startedAt;
  final Duration duration;
  final List<TripPoint> points;

  double get distanceKm {
    if (points.length < 2) return 0;

    const distance = Distance();
    var totalMeters = 0.0;

    for (var i = 1; i < points.length; i++) {
      totalMeters += distance.as(
        LengthUnit.Meter,
        points[i - 1].position,
        points[i].position,
      );
    }

    return totalMeters / 1000;
  }

  int get topSpeedKmh {
    if (points.isEmpty) return 0;
    return points
        .map((point) => point.speedKmh)
        .reduce((a, b) => a > b ? a : b);
  }

  int get averageSpeedKmh {
    if (points.isEmpty) return 0;
    final totalSpeed = points.fold<int>(
      0,
      (sum, point) => sum + point.speedKmh,
    );
    return (totalSpeed / points.length).round();
  }

  int get averageHeading {
    if (points.isEmpty) return 0;
    final totalHeading = points.fold<int>(
      0,
      (sum, point) => sum + point.heading,
    );
    return (totalHeading / points.length).round();
  }
}

class TripPoint {
  const TripPoint({
    required this.position,
    required this.speedKmh,
    required this.heading,
    required this.recordedOffset,
  });

  final LatLng position;
  final int speedKmh;
  final int heading;
  final Duration recordedOffset;
}

final sampleTrips = <TripSummary>[
  TripSummary(
    id: 'trip-104',
    title: 'Ranchi Lake loop',
    subtitle: 'Lake Road to Morabadi Ground',
    startedAt: DateTime(2026, 8, 9, 17, 30),
    duration: const Duration(minutes: 28),
    points: const [
      TripPoint(
        position: LatLng(23.3636, 85.3268),
        speedKmh: 12,
        heading: 64,
        recordedOffset: Duration.zero,
      ),
      TripPoint(
        position: LatLng(23.3618, 85.3297),
        speedKmh: 22,
        heading: 112,
        recordedOffset: Duration(minutes: 4),
      ),
      TripPoint(
        position: LatLng(23.3592, 85.3319),
        speedKmh: 38,
        heading: 146,
        recordedOffset: Duration(minutes: 9),
      ),
      TripPoint(
        position: LatLng(23.3562, 85.3303),
        speedKmh: 31,
        heading: 202,
        recordedOffset: Duration(minutes: 15),
      ),
      TripPoint(
        position: LatLng(23.3546, 85.3268),
        speedKmh: 45,
        heading: 247,
        recordedOffset: Duration(minutes: 21),
      ),
      TripPoint(
        position: LatLng(23.3569, 85.3233),
        speedKmh: 18,
        heading: 319,
        recordedOffset: Duration(minutes: 28),
      ),
    ],
  ),
  TripSummary(
    id: 'trip-103',
    title: 'Station pickup',
    subtitle: 'Ranchi Station to Harmu',
    startedAt: DateTime(2026, 8, 6, 9, 10),
    duration: const Duration(minutes: 22),
    points: const [
      TripPoint(
        position: LatLng(23.3508, 85.3346),
        speedKmh: 8,
        heading: 48,
        recordedOffset: Duration.zero,
      ),
      TripPoint(
        position: LatLng(23.3542, 85.3377),
        speedKmh: 28,
        heading: 32,
        recordedOffset: Duration(minutes: 5),
      ),
      TripPoint(
        position: LatLng(23.3586, 85.3401),
        speedKmh: 36,
        heading: 18,
        recordedOffset: Duration(minutes: 11),
      ),
      TripPoint(
        position: LatLng(23.3637, 85.3398),
        speedKmh: 41,
        heading: 354,
        recordedOffset: Duration(minutes: 16),
      ),
      TripPoint(
        position: LatLng(23.3692, 85.3372),
        speedKmh: 19,
        heading: 332,
        recordedOffset: Duration(minutes: 22),
      ),
    ],
  ),
  TripSummary(
    id: 'trip-102',
    title: 'Campus check',
    subtitle: 'Morabadi to Kanke Road',
    startedAt: DateTime(2026, 8, 2, 14, 5),
    duration: const Duration(minutes: 34),
    points: const [
      TripPoint(
        position: LatLng(23.3709, 85.3206),
        speedKmh: 10,
        heading: 294,
        recordedOffset: Duration.zero,
      ),
      TripPoint(
        position: LatLng(23.3742, 85.3172),
        speedKmh: 24,
        heading: 312,
        recordedOffset: Duration(minutes: 7),
      ),
      TripPoint(
        position: LatLng(23.3798, 85.3145),
        speedKmh: 43,
        heading: 338,
        recordedOffset: Duration(minutes: 15),
      ),
      TripPoint(
        position: LatLng(23.3854, 85.3137),
        speedKmh: 48,
        heading: 3,
        recordedOffset: Duration(minutes: 24),
      ),
      TripPoint(
        position: LatLng(23.3906, 85.3159),
        speedKmh: 26,
        heading: 29,
        recordedOffset: Duration(minutes: 34),
      ),
    ],
  ),
];

TripSummary? findSampleTrip(String id) {
  for (final trip in sampleTrips) {
    if (trip.id == id) return trip;
  }

  return null;
}
