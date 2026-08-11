
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:atlocator/features/location/location_socket_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;
  late final ValueNotifier<double> _headingNotifier;

  LatLng? _currentLocation;
  final List<LatLng> _travelTrail = [];
  // Temporary dummy members for UI/testing when no real members available
  final List<MemberLocation> _dummyMembers = [
    MemberLocation(
      userId: 1001,
      latitude: 23.3446,
      longitude: 85.3093,
      speedKmh: 12,
      heading: 85,
      accuracy: 5,
      recordedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      displayName: 'Alice',
    ),
    MemberLocation(
      userId: 1002,
      latitude: 23.3439,
      longitude: 85.3101,
      speedKmh: 7,
      heading: 200,
      accuracy: 8,
      recordedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
      displayName: 'Bob',
    ),
    MemberLocation(
      userId: 1003,
      latitude: 23.3451,
      longitude: 85.3089,
      speedKmh: 0,
      heading: 0,
      accuracy: 4,
      recordedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 6)),
      displayName: 'Carol',
    ),
  ];
  double _currentHeading = 0;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _headingStream;
  StreamSubscription<GyroscopeEvent>? _gyroscopeStream;
  DateTime? _lastGyroscopeAt;

  bool _followUser = true;
  bool _hasCompassHeading = false;
  bool _locating = true;
  String? _locationMessage;

  static const _maxTrailPoints = 500;
  static const _minTrailPointDistanceMeters = 2.0;

  @override
  void initState() {
    super.initState();

    _headingNotifier = ValueNotifier(0);
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );

    _startLocationTracking();
    _startHeadingTracking();
    _startGyroscopeHeadingTracking();
  }

  void _startHeadingTracking() {
    final events = FlutterCompass.events;
    if (events == null) return;

    _headingStream = events.listen((event) {
      final heading = event.heading;

      if (heading == null || !heading.isFinite || !mounted) return;

      _setHeading(heading);
      _hasCompassHeading = true;
    });
  }

  void _startGyroscopeHeadingTracking() {
    _gyroscopeStream = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) {
      final lastTimestamp = _lastGyroscopeAt;
      _lastGyroscopeAt = event.timestamp;

      if (lastTimestamp == null || !mounted) return;

      final elapsedSeconds =
          event.timestamp.difference(lastTimestamp).inMicroseconds / 1000000;

      if (elapsedSeconds <= 0 || elapsedSeconds > 1) return;
      if (event.z.abs() < 0.01) return;

      final deltaDegrees = event.z * elapsedSeconds * 180 / math.pi;
      _setHeading(_currentHeading - deltaDegrees);
    }, onError: (_) {
      _lastGyroscopeAt = null;
    });
  }

  Future<void> _startLocationTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _setLocationMessage("Turn on location services to show your position.");
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setLocationMessage("Allow location permission to show your position.");
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 12));
      _showPosition(position);
    } on Object {
      _setLocationMessage("Finding your current location...");
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_showPosition, onError: (_) {
          _setLocationMessage("Unable to read location. Try again.");
        });
  }

  Future<void> _goToMyLocation() async {
    if (_currentLocation == null) {
      setState(() {
        _locating = true;
        _locationMessage = "Finding your current location...";
      });
      await _startLocationTracking();
      return;
    }

    if (_currentLocation == null) return;

    setState(() => _followUser = true);

    await _animatedMapController.animateTo(
      dest: _currentLocation,
      zoom: 18,
      rotation: 0,
    );
  }

  void _showPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);

    if (!mounted) return;

    setState(() {
      _currentLocation = point;
      _addTrailPoint(point);
      if (!_hasCompassHeading &&
          position.heading.isFinite &&
          position.heading >= 0) {
        _setHeading(position.heading, rebuild: false);
      }
      _locating = false;
      _locationMessage = null;
    });

    if (_followUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _animatedMapController.animateTo(
          dest: point,
          zoom: _animatedMapController.mapController.camera.zoom < 5
              ? 17
              : _animatedMapController.mapController.camera.zoom,
        );
      });
    }
  }

  void _setLocationMessage(String message) {
    if (!mounted) return;

    setState(() {
      _locating = false;
      _locationMessage = message;
    });
  }

  void _addTrailPoint(LatLng point) {
    if (_travelTrail.isNotEmpty) {
      final previousPoint = _travelTrail.last;
      final distance = const Distance().as(
        LengthUnit.Meter,
        previousPoint,
        point,
      );

      if (distance < _minTrailPointDistanceMeters) return;
    }

    _travelTrail.add(point);

    if (_travelTrail.length > _maxTrailPoints) {
      _travelTrail.removeRange(0, _travelTrail.length - _maxTrailPoints);
    }
  }

  void _clearTrail() {
    final point = _currentLocation;

    setState(() {
      _travelTrail
        ..clear()
        ..addAll(point == null ? const [] : [point]);
    });
  }

  double _normalizeHeading(double heading) {
    final normalizedHeading = heading % 360;
    return normalizedHeading < 0 ? normalizedHeading + 360 : normalizedHeading;
  }

  void _setHeading(double heading, {bool rebuild = true}) {
    final normalizedHeading = _normalizeHeading(heading);

    _currentHeading = normalizedHeading;
    _headingNotifier.value = normalizedHeading;

    if (rebuild && mounted) {
      setState(() {});
    }
  }

  void _showMemberSheet(BuildContext context, MemberLocation member, LatLng point) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.displayName ?? 'User ${member.userId}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('ID: ${member.userId}'),
            Text('Speed: ${member.speedKmh} km/h'),
            Text('Heading: ${member.heading}°'),
            Text('Accuracy: ${member.accuracy} m'),
            Text('Last: ${member.recordedAt.toLocal()}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _animatedMapController.animateTo(dest: point, zoom: 17);
              },
              child: const Text('Fly to user'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _headingStream?.cancel();
    _gyroscopeStream?.cancel();
    _headingNotifier.dispose();
    _animatedMapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _animatedMapController.mapController,
          options: MapOptions(
            initialCenter: const LatLng(23.3441, 85.3096),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              rotationThreshold: 20,
              enableMultiFingerGestureRace: true,
            ),
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) {
                _followUser = false;
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.at_locator',
            ),
            if (_travelTrail.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _travelTrail,
                    color: const Color(0xff006D77),
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  if (_travelTrail.isNotEmpty)
                    Marker(
                      point: _travelTrail.first,
                      width: 34,
                      height: 34,
                      child: const _TrailStartMarker(),
                    ),
                  Marker(
                    point: _currentLocation!,
                    width: 44,
                    height: 44,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _headingNotifier,
                      builder: (context, heading, _) {
                        return _HeadingMarker(headingDegrees: heading);
                      },
                    ),
                  ),
                ],
              ),
            // Other members' markers from socket + dummy members
            ValueListenableBuilder<LocationSocketSnapshot>(
              valueListenable: LocationSocketService.instance.snapshotNotifier,
              builder: (context, snapshot, _) {
                final allMembers = [
                  ...snapshot.members.values,
                  ..._dummyMembers,
                ];

                if (allMembers.isEmpty) return const SizedBox.shrink();

                final markers = allMembers.map<Marker>((member) {
                  final point = LatLng(member.latitude, member.longitude);
                  return Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showMemberSheet(context, member, point),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withOpacity(.95),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (member.displayName != null && member.displayName!.isNotEmpty)
                                ? member.displayName!.substring(0, 1).toUpperCase()
                                : member.userId.toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList();

                return MarkerLayer(markers: markers);
              },
            ),
          ],
        ),
        if (_locationMessage != null)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _LocationNotice(message: _locationMessage!),
          ),
        // Compact action buttons: users on left, locate on right — aligned vertically
        Positioned(
          bottom: 18,
          left: 12,
          child: FloatingActionButton(
            heroTag: 'users_compact',
            mini: true,
            backgroundColor: const Color(0xff006D77),
            elevation: 8,
            tooltip: 'Show connected users',
            onPressed: () {
              final snapshot = LocationSocketService.instance.snapshot;
              final members = [
                ...snapshot.members.values,
                ..._dummyMembers,
              ];

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                builder: (context) {
                  return StatefulBuilder(builder: (context, setState) {
                    String query = '';
                    List<MemberLocation> filtered = members;

                    void applyFilter(String q) {
                      query = q.trim().toLowerCase();
                      filtered = members.where((m) {
                        final name = (m.displayName ?? '').toLowerCase();
                        return name.contains(query) || m.userId.toString().contains(query);
                      }).toList();
                    }

                    applyFilter('');

                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: SizedBox(
                          height: math.min(520, filtered.length * 82 + 140),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Search by name or id',
                                        prefixIcon: const Icon(Icons.search),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          applyFilter(val);
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Close',
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(child: Text('No users found'))
                                    : ListView.separated(
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, i) {
                                          final m = filtered[i];
                                          final distanceMeters = _currentLocation == null
                                              ? null
                                              : const Distance().as(
                                                  LengthUnit.Meter,
                                                  _currentLocation!,
                                                  LatLng(m.latitude, m.longitude),
                                                );

                                          final distanceText = distanceMeters == null
                                              ? '—'
                                              : (distanceMeters >= 1000
                                                  ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
                                                  : '${distanceMeters.round()} m');

                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            leading: CircleAvatar(
                                              radius: 22,
                                              backgroundColor: Colors.orange,
                                              child: Text(
                                                m.displayName != null && m.displayName!.isNotEmpty
                                                    ? m.displayName!.substring(0, 1).toUpperCase()
                                                    : m.userId.toString(),
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                            title: Text(m.displayName ?? 'User ${m.userId}'),
                                            subtitle: Text('Last: ${m.recordedAt.toLocal()} • $distanceText'),
                                            trailing: IconButton(
                                              tooltip: 'Fly to user',
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                _animatedMapController.animateTo(
                                                  dest: LatLng(m.latitude, m.longitude),
                                                  zoom: 17,
                                                );
                                              },
                                              icon: const Icon(Icons.flight_takeoff_rounded),
                                            ),
                                            onTap: () {
                                              Navigator.of(context).pop();
                                              _animatedMapController.animateTo(
                                                dest: LatLng(m.latitude, m.longitude),
                                                zoom: 17,
                                              );
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              );
            },
            child: const Icon(Icons.people_rounded, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 18,
          right: 12,
          child: FloatingActionButton(
            heroTag: "locate_compact",
            mini: true,
            backgroundColor: const Color(0xff0B7285),
            tooltip: 'Center on my location',
            elevation: 8,
            onPressed: _goToMyLocation,
            child: _locating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Icon(
                    _followUser ? Icons.my_location : Icons.location_searching,
                    color: Colors.white,
                  ),
          ),
        ),
      ],
    );
  }
}

class _TrailStartMarker extends StatelessWidget {
  const _TrailStartMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff006D77),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.flag_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _HeadingMarker extends StatelessWidget {
  const _HeadingMarker({required this.headingDegrees});

  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: headingDegrees * math.pi / 180,
      child: CustomPaint(
        painter: _HeadingMarkerPainter(),
      ),
    );
  }
}

class _HeadingMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final pointerPaint = Paint()
      ..color = const Color(0xff006D77)
      ..style = PaintingStyle.fill;
    final bodyPaint = Paint()
      ..color = const Color(0xff0B7285)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pointer = ui.Path()
      ..moveTo(center.dx, 3)
      ..lineTo(center.dx - 7, center.dy - 3)
      ..lineTo(center.dx + 7, center.dy - 3)
      ..close();

    canvas.drawCircle(center.translate(0, 2), 12, shadowPaint);
    canvas.drawPath(pointer.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(pointer, pointerPaint);
    canvas.drawCircle(center, 11, bodyPaint);
    canvas.drawCircle(center, 11, ringPaint);
    canvas.drawCircle(center, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HeadingMarkerPainter oldDelegate) => false;
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Color(0xff006D77),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xff102A43),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
