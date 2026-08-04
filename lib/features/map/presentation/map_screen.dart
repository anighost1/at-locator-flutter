// NOTE:
// This file demonstrates the architecture using AnimatedMapController.
// You will need to finish wiring the AnimatedMapController calls if you
// want additional custom behavior.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;
  late final ValueNotifier<double> _headingNotifier;

  LatLng? _currentLocation;
  double _currentHeading = 0;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _headingStream;

  bool _followUser = true;
  bool _hasCompassHeading = false;
  bool _locating = true;
  String? _locationMessage;

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
  }

  void _startHeadingTracking() {
    final events = FlutterCompass.events;
    if (events == null) return;

    _headingStream = events.listen((event) {
      final heading = event.heading;

      if (heading == null || !heading.isFinite || !mounted) return;

      setState(() {
        _currentHeading = _normalizeHeading(heading);
        _headingNotifier.value = _currentHeading;
        _hasCompassHeading = true;
      });
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
      if (!_hasCompassHeading &&
          position.heading.isFinite &&
          position.heading >= 0) {
        _currentHeading = _normalizeHeading(position.heading);
        _headingNotifier.value = _currentHeading;
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

  double _normalizeHeading(double heading) {
    final normalizedHeading = heading % 360;
    return normalizedHeading < 0 ? normalizedHeading + 360 : normalizedHeading;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _headingStream?.cancel();
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
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
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
          ],
        ),
        if (_locationMessage != null)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _LocationNotice(message: _locationMessage!),
          ),
        Positioned(
          bottom: 20,
          right: 16,
          child: FloatingActionButton(
            heroTag: "locate",
            mini: true,
            onPressed: _goToMyLocation,
            child: _locating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(
                    _followUser ? Icons.my_location : Icons.location_searching,
                  ),
          ),
        ),
      ],
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
