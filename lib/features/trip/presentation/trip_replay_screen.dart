import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:atlocator/core/api/api_exception.dart';
import 'package:atlocator/core/routing/route_names.dart';
import 'package:atlocator/features/trip/models/trip_models.dart';
import 'package:atlocator/features/trip/repository/trip_repository.dart';

class TripReplayScreen extends StatefulWidget {
  const TripReplayScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripReplayScreen> createState() => _TripReplayScreenState();
}

class _TripReplayScreenState extends State<TripReplayScreen> {
  final _repository = TripRepository();
  final _mapController = MapController();

  Timer? _timer;
  TripSummary? _summary;
  bool _loading = true;
  bool _isPlaying = false;
  String? _errorMessage;
  int _pointIndex = 0;

  int? get _tripId => int.tryParse(widget.tripId);

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final tripId = _tripId;
    if (tripId == null) {
      setState(() {
        _loading = false;
        _errorMessage = "Invalid trip id.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _repository.getSummary(tripId);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _pointIndex = 0;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
        _loading = false;
      });
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _pause();
      return;
    }

    final summary = _summary;
    if (summary == null || summary.points.isEmpty) return;

    if (_pointIndex >= summary.points.length - 1) {
      setState(() => _pointIndex = 0);
    }

    setState(() => _isPlaying = true);
    _timer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;

      final lastIndex = summary.points.length - 1;
      if (_pointIndex >= lastIndex) {
        _pause();
        return;
      }

      setState(() => _pointIndex += 1);
      _moveMapToCurrentPoint();
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _setReplayPosition(double value) {
    _pause();
    setState(() => _pointIndex = value.round());
    _moveMapToCurrentPoint();
  }

  void _moveMapToCurrentPoint() {
    final summary = _summary;
    if (summary == null || summary.points.isEmpty) return;
    _mapController.move(summary.points[_pointIndex].position, 16);
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;

    return "Unable to load trip replay. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ReplayNotice(
        icon: Icons.error_outline_rounded,
        title: _errorMessage!,
        actionLabel: "Retry",
        onAction: _loadSummary,
      );
    }

    if (summary == null || summary.points.isEmpty) {
      return _ReplayNotice(
        icon: Icons.route_outlined,
        title: "No replay points found for trip ${widget.tripId}",
        actionLabel: "Back to Trips",
        onAction: () => context.go(RouteNames.trip),
      );
    }

    final currentPoint = summary.points[_pointIndex];
    final replayedPoints = summary.points
        .take(_pointIndex + 1)
        .map((point) => point.position)
        .toList();
    final allPoints = summary.points.map((point) => point.position).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ReplayHeader(
            tripId: widget.tripId,
            summary: summary,
            currentPoint: currentPoint,
            onBack: () => context.go(RouteNames.trip),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ReplayMap(
                mapController: _mapController,
                currentPoint: currentPoint,
                allPoints: allPoints,
                replayedPoints: replayedPoints,
              ),
              const SizedBox(height: 16),
              _ReplayControls(
                summary: summary,
                currentPoint: currentPoint,
                pointIndex: _pointIndex,
                isPlaying: _isPlaying,
                onPlayPause: _togglePlayback,
                onChanged: _setReplayPosition,
              ),
              const SizedBox(height: 16),
              _StatsGrid(summary: summary, currentPoint: currentPoint),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ReplayHeader extends StatelessWidget {
  const _ReplayHeader({
    required this.tripId,
    required this.summary,
    required this.currentPoint,
    required this.onBack,
  });

  final String tripId;
  final TripSummary summary;
  final TripPoint currentPoint;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff102A43), Color(0xff006D77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: "Back to trips",
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Trip #$tripId replay",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${summary.totalPoints} points - ${_durationLabel(Duration(seconds: summary.durationSeconds))}",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayMap extends StatelessWidget {
  const _ReplayMap({
    required this.mapController,
    required this.currentPoint,
    required this.allPoints,
    required this.replayedPoints,
  });

  final MapController mapController;
  final TripPoint currentPoint;
  final List<LatLng> allPoints;
  final List<LatLng> replayedPoints;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 320,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: allPoints.first, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.at_locator',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: allPoints,
                  color: Colors.white,
                  strokeWidth: 9,
                ),
                Polyline(
                  points: allPoints,
                  color: const Color(0xff8D99AE),
                  strokeWidth: 5,
                ),
                Polyline(
                  points: replayedPoints,
                  color: const Color(0xff006D77),
                  strokeWidth: 6,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: allPoints.first,
                  width: 34,
                  height: 34,
                  child: const _ReplayFlag(icon: Icons.flag_rounded),
                ),
                Marker(
                  point: allPoints.last,
                  width: 34,
                  height: 34,
                  child: const _ReplayFlag(icon: Icons.location_on_rounded),
                ),
                Marker(
                  point: currentPoint.position,
                  width: 46,
                  height: 46,
                  child: _ReplayHeadingMarker(
                    heading: currentPoint.heading.round(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayControls extends StatelessWidget {
  const _ReplayControls({
    required this.summary,
    required this.currentPoint,
    required this.pointIndex,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onChanged,
  });

  final TripSummary summary;
  final TripPoint currentPoint;
  final int pointIndex;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: onPlayPause,
                tooltip: isPlaying ? "Pause replay" : "Play replay",
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xff006D77),
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeLabel(currentPoint.recordedAt),
                      style: const TextStyle(
                        color: Color(0xff102A43),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Point ${pointIndex + 1} of ${summary.points.length}",
                      style: TextStyle(
                        color: Colors.blueGrey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: pointIndex.toDouble(),
            min: 0,
            max: (summary.points.length - 1).toDouble(),
            divisions: summary.points.length - 1,
            activeColor: const Color(0xff006D77),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary, required this.currentPoint});

  final TripSummary summary;
  final TripPoint currentPoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.18,
          children: [
            _MetricCard(
              icon: Icons.speed_rounded,
              label: "Current speed",
              value: currentPoint.speedKmh.toStringAsFixed(1),
              unit: "km/h",
            ),
            _MetricCard(
              icon: Icons.rocket_launch_rounded,
              label: "Top speed",
              value: summary.topSpeed.toStringAsFixed(1),
              unit: "km/h",
            ),
            _MetricCard(
              icon: Icons.query_stats_rounded,
              label: "Average speed",
              value: summary.averageSpeed.toStringAsFixed(1),
              unit: "km/h",
            ),
            _MetricCard(
              icon: Icons.explore_rounded,
              label: "Heading",
              value: currentPoint.heading.round().toString(),
              unit: "deg",
            ),
            _MetricCard(
              icon: Icons.gps_fixed_rounded,
              label: "Accuracy",
              value: currentPoint.accuracy.toStringAsFixed(0),
              unit: "m",
            ),
            _MetricCard(
              icon: Icons.straighten_rounded,
              label: "Distance",
              value: summary.distanceKm.toStringAsFixed(2),
              unit: "km",
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE4ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xff006D77), size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.blueGrey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RichText(
                  text: TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Color(0xff102A43),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(
                        text: " $unit",
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE4ECEF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff102A43).withValues(alpha: .06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReplayFlag extends StatelessWidget {
  const _ReplayFlag({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff102A43),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }
}

class _ReplayHeadingMarker extends StatelessWidget {
  const _ReplayHeadingMarker({required this.heading});

  final int heading;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff006D77),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _ReplayNotice extends StatelessWidget {
  const _ReplayNotice({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xff006D77), size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xff102A43),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);

  if (minutes == 0) return "${seconds}s";
  if (seconds == 0) return "${minutes}m";

  return "${minutes}m ${seconds}s";
}

String _timeLabel(DateTime? dateTime) {
  if (dateTime == null) return "Recorded point";

  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, "0");
  final minute = local.minute.toString().padLeft(2, "0");
  final second = local.second.toString().padLeft(2, "0");

  return "$hour:$minute:$second";
}
