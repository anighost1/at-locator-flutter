import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlocator/core/routing/route_names.dart';
import 'package:atlocator/features/location/location_socket_service.dart';
import 'package:atlocator/features/trip/presentation/trip_sample_data.dart';

class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSocketSnapshot>(
      valueListenable: LocationSocketService.instance.snapshotNotifier,
      builder: (context, snapshot, _) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TripHeader(snapshot: snapshot)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  snapshot.isStarted
                      ? _OngoingTripPanel(snapshot: snapshot)
                      : const _CreateTripPanel(),
                  const SizedBox(height: 16),
                  _TripHistoryPanel(trips: sampleTrips),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.snapshot});

  final LocationSocketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
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
            snapshot.isStarted
                ? "Trip #${snapshot.tripId} is live"
                : "Create a new trip",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.isStarted
                ? "Room ${snapshot.roomId} is collecting location packets from this device."
                : "Start a live trip, or replay a previous route from your trip history.",
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
  const _CreateTripPanel();

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
          const SizedBox(height: 12),
          Text(
            "Create a trip to begin sharing live GPS updates with the configured trip room.",
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              await LocationSocketService.instance.start();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Trip tracking started")),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text("Create Trip"),
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
  const _OngoingTripPanel({required this.snapshot});

  final LocationSocketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
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
          _InfoRow(label: "Trip", value: "#${snapshot.tripId}"),
          const SizedBox(height: 10),
          _InfoRow(label: "Room", value: snapshot.roomId),
          const SizedBox(height: 10),
          _InfoRow(
            label: "Latest speed",
            value: location == null ? "-- km/h" : "${location.speedKmh} km/h",
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: "Heading",
            value: location == null ? "-- deg" : "${location.heading} deg",
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await LocationSocketService.instance.stop();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Trip tracking stopped")),
              );
            },
            icon: const Icon(Icons.stop_rounded),
            label: const Text("End Trip"),
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
  }
}

class _TripHistoryPanel extends StatelessWidget {
  const _TripHistoryPanel({required this.trips});

  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: "Trip history", action: "${trips.length} trips"),
          const SizedBox(height: 14),
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

  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(RouteNames.tripReplayPath(trip.id)),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xffE8F3F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.replay_rounded, color: Color(0xff006D77)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff102A43),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${trip.subtitle} - ${trip.distanceKm.toStringAsFixed(1)} km",
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${trip.duration.inMinutes} min",
                  style: const TextStyle(
                    color: Color(0xff102A43),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${trip.topSpeedKmh} km/h max",
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
        Text(
          value,
          style: const TextStyle(
            color: Color(0xff102A43),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
