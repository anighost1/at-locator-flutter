// NOTE:
// This file demonstrates the architecture using AnimatedMapController.
// You will need to finish wiring the AnimatedMapController calls if you
// want additional custom behavior.

import 'dart:async';

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

  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;

  bool _followUser = true;

  @override
  void initState() {
    super.initState();

    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );

    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
          final point = LatLng(pos.latitude, pos.longitude);

          if (!mounted) return;

          setState(() => _currentLocation = point);

          if (_followUser) {
            _animatedMapController.animateTo(
              dest: point,
              zoom: _animatedMapController.mapController.camera.zoom < 5
                  ? 17
                  : _animatedMapController.mapController.camera.zoom,
            );
          }
        });
  }

  Future<void> _goToMyLocation() async {
    if (_currentLocation == null) return;

    setState(() => _followUser = true);

    await _animatedMapController.animateTo(
      dest: _currentLocation,
      zoom: 18,
      rotation: 0,
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
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
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 8, color: Colors.black26),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          bottom: 20,
          right: 16,
          child: FloatingActionButton(
            heroTag: "locate",
            mini: true,
            onPressed: _goToMyLocation,
            child: Icon(
              _followUser ? Icons.my_location : Icons.location_searching,
            ),
          ),
        ),
      ],
    );
  }
}
