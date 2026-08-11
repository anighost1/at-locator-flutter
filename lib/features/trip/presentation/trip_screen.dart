import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlocator/core/api/api_exception.dart';
import 'package:atlocator/core/routing/route_names.dart';
import 'package:atlocator/features/location/location_socket_service.dart';
import 'package:atlocator/features/trip/models/trip_models.dart';
import 'package:atlocator/features/trip/repository/trip_repository.dart';
import 'package:atlocator/features/trip/session/trip_session.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _repository = TripRepository();
  final _tripNameController = TextEditingController(text: "The Trip");

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  Trip? _ongoingTrip;
  List<Trip> _trips = const [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final ongoing = await _repository.getOngoingTrip();
      final trips = await _repository.getTrips();

      if (ongoing != null && ongoing.tripCode != null) {
        await TripSession.save(ongoing);
        await _startTripSocket(ongoing);
      } else {
        await TripSession.clear();
        await LocationSocketService.instance.start();
      }

      if (!mounted) return;
      setState(() {
        _ongoingTrip = ongoing;
        _trips = trips;
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

  Future<void> _createTrip() async {
    final name = _tripNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final trip = await _repository.createTrip(name);

      if (trip.tripCode != null) {
        await TripSession.save(trip);
        await LocationSocketService.instance.stop();
        await _startTripSocket(trip);
      }

      final trips = await _repository.getTrips();

      if (!mounted) return;
      setState(() {
        _ongoingTrip = trip;
        _trips = trips;
        _saving = false;
      });
      _showSnack("Trip created with code ${trip.tripCode ?? "-"}");
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
        _saving = false;
      });
    }
  }

  Future<void> _endTrip() async {
    final trip = _ongoingTrip;
    if (trip == null) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await _repository.endTrip(trip.id);
      await TripSession.clear();
      await LocationSocketService.instance.start();
      final trips = await _repository.getTrips();

      if (!mounted) return;
      setState(() {
        _ongoingTrip = null;
        _trips = trips;
        _saving = false;
      });
      _showSnack("Trip ended");
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
        _saving = false;
      });
    }
  }

  Future<void> _startTripSocket(Trip trip) async {
    final tripCode = trip.tripCode;
    if (tripCode == null || tripCode.isEmpty) return;

    await LocationSocketService.instance.start(
      tripId: trip.id,
      roomId: tripCode,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;

    return "Unable to load trip details. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TripHeader(ongoingTrip: _ongoingTrip)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_errorMessage != null) ...[
                  _ErrorPanel(message: _errorMessage!, onRetry: _loadTrips),
                  const SizedBox(height: 16),
                ],
                if (_loading)
                  const _LoadingPanel()
                else if (_ongoingTrip != null)
                  _OngoingTripPanel(
                    trip: _ongoingTrip!,
                    saving: _saving,
                    onEndTrip: _endTrip,
                  )
                else
                  _CreateTripPanel(
                    controller: _tripNameController,
                    saving: _saving,
                    onCreateTrip: _createTrip,
                  ),
                const SizedBox(height: 16),
                _TripHistoryPanel(trips: _trips),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.ongoingTrip});

  final Trip? ongoingTrip;

  @override
  Widget build(BuildContext context) {
    final trip = ongoingTrip;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
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
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .26),
                  ),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Trips",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            trip == null ? "Create a new trip" : "${trip.name} is live",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trip == null
                ? "Create a trip to receive a trip code and join the socket room with it."
                : "Socket room code: ${trip.tripCode ?? "-"}",
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateTripPanel extends StatelessWidget {
  const _CreateTripPanel({
    required this.controller,
    required this.saving,
    required this.onCreateTrip,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onCreateTrip;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.add_road_rounded,
            title: "No ongoing trip",
            color: Color(0xffF4A261),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: "Trip name",
              prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
              filled: true,
              fillColor: const Color(0xffF7FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffD8E5E9)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffD8E5E9)),
              ),
            ),
            onSubmitted: (_) => saving ? null : onCreateTrip(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : onCreateTrip,
            icon: saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(saving ? "Creating" : "Create Trip"),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff006D77),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OngoingTripPanel extends StatelessWidget {
  const _OngoingTripPanel({
    required this.trip,
    required this.saving,
    required this.onEndTrip,
  });

  final Trip trip;
  final bool saving;
  final VoidCallback onEndTrip;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSocketSnapshot>(
      valueListenable: LocationSocketService.instance.snapshotNotifier,
      builder: (context, snapshot, _) {
        final location = snapshot.latestLocation;

        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: _PanelTitle(
                      icon: Icons.sensors_rounded,
                      title: "Ongoing trip",
                      color: Color(0xff2A9D8F),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffE4F8F4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "LIVE",
                      style: TextStyle(
                        color: Color(0xff1D7E73),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoRow(label: "Trip", value: "#${trip.id}"),
              const SizedBox(height: 10),
              _InfoRow(label: "Name", value: trip.name),
              const SizedBox(height: 10),
              _InfoRow(label: "Trip code", value: trip.tripCode ?? "-"),
              const SizedBox(height: 10),
              _InfoRow(
                label: "Socket",
                value: snapshot.isConnected ? "Connected" : "Connecting",
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: "Latest speed",
                value: location == null
                    ? "-- km/h"
                    : "${location.speedKmh} km/h",
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: "Heading",
                value: location == null ? "-- deg" : "${location.heading} deg",
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: saving ? null : onEndTrip,
                icon: saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.stop_rounded),
                label: Text(saving ? "Ending" : "End Trip"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff006D77),
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Color(0xffB8DAD8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripHistoryPanel extends StatelessWidget {
  const _TripHistoryPanel({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: "Trip history", action: "${trips.length} trips"),
          const SizedBox(height: 14),
          if (trips.isEmpty)
            Text(
              "No trips yet.",
              style: TextStyle(
                color: Colors.blueGrey.shade500,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final trip in trips) ...[
              _TripHistoryRow(trip: trip),
              if (trip != trips.last) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _TripHistoryRow extends StatelessWidget {
  const _TripHistoryRow({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(RouteNames.tripReplayPath(trip.id.toString())),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: trip.isOngoing
                    ? const Color(0xffE4F8F4)
                    : const Color(0xffE8F3F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                trip.isOngoing ? Icons.sensors_rounded : Icons.replay_rounded,
                color: const Color(0xff006D77),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff102A43),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _dateRangeLabel(trip),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              trip.isOngoing ? "LIVE" : "Replay",
              style: TextStyle(
                color: trip.isOngoing
                    ? const Color(0xff1D7E73)
                    : Colors.blueGrey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xffB42318)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xff102A43),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            tooltip: "Retry",
            icon: const Icon(Icons.refresh_rounded),
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

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xff102A43),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xff102A43),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          action,
          style: TextStyle(
            color: Colors.blueGrey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade500,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xff102A43),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

String _dateRangeLabel(Trip trip) {
  final start = trip.startedAt;
  final end = trip.endedAt;

  if (start == null) return trip.isOngoing ? "Ongoing" : "Completed";

  final startLabel = _dateLabel(start);
  if (end == null) return "Started $startLabel";

  return "$startLabel - ${_dateLabel(end)}";
}

String _dateLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, "0");
  final month = local.month.toString().padLeft(2, "0");
  final hour = local.hour.toString().padLeft(2, "0");
  final minute = local.minute.toString().padLeft(2, "0");

  return "$day/$month/$hour:$minute";
}
