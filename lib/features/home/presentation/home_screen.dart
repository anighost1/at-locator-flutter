import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlocator/core/routing/route_names.dart';
import 'package:atlocator/features/auth/session/auth_session.dart';
import 'package:atlocator/features/location/location_socket_service.dart';
import 'package:atlocator/features/trip/session/trip_session.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // HomeScreen no longer owns socket startup; it is handled by the app shell.
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSocketSnapshot>(
      valueListenable: LocationSocketService.instance.snapshotNotifier,
      builder: (context, snapshot, _) {
        final members = [
          _TripMember(
            "User #${snapshot.userId ?? AuthSession.userId ?? "-"}",
            "Current device",
            snapshot.isConnected ? "Live" : "Offline",
            snapshot.isConnected
                ? const Color(0xff2A9D8F)
                : const Color(0xff8D99AE),
          ),
        ];

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                snapshot: snapshot,
                onLogout: () async {
                  await LocationSocketService.instance.stop();
                  await AuthSession.clear();
                  await TripSession.clear();
                  if (!context.mounted) return;
                  context.go(RouteNames.login);
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _TelemetryGrid(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _CreateTripPanel(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _MembersPanel(members: members),
                  if (snapshot.recentPackets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _GpsPacketsPanel(packets: snapshot.recentPackets),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.snapshot, required this.onLogout});

  final LocationSocketSnapshot snapshot;
  final VoidCallback onLogout;

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
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.26)),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AT Locator",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "GPS trip sharing",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onLogout,
                tooltip: "Logout",
                icon: const Icon(Icons.logout_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(.15),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            snapshot.tripId > 0 ? "Trip #${snapshot.tripId}" : "No active trip",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.isConnected
                ? snapshot.roomId.isNotEmpty
                    ? "Your device is sending GPS data to ${snapshot.roomId}."
                    : "Socket connected and waiting for an active trip."
                : snapshot.roomId.isNotEmpty
                    ? "Connecting your device to ${snapshot.roomId}."
                    : "Connecting your device to the server.",
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                icon: Icons.sensors_rounded,
                label: snapshot.isConnected
                    ? "Socket connected"
                    : "Socket connecting",
              ),
              if (snapshot.isConnected && snapshot.roomId.isEmpty)
                _StatusPill(
                  icon: Icons.hourglass_bottom_rounded,
                  label: "Waiting for active trip",
                  backgroundColor: const Color(0xffF4A261).withOpacity(.2),
                  borderColor: const Color(0xffF4A261).withOpacity(.38),
                  textColor: const Color(0xffffffff),
                ),
              _StatusPill(
                icon: Icons.gps_fixed_rounded,
                label: snapshot.hasLocation ? "GPS locked" : "GPS searching",
              ),
              _StatusPill(
                icon: Icons.person_rounded,
                label: "User ${snapshot.userId ?? AuthSession.userId ?? "-"}",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconTile(
                icon: Icons.route_rounded,
                color: Color(0xff006D77),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Active trip",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff102A43),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Ranchi Lake to Morabadi Ground",
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const _LiveBadge(),
            ],
          ),
          const SizedBox(height: 18),
          const _RanchiMapView(),
        ],
      ),
    );
  }
}

class _TelemetryGrid extends StatelessWidget {
  const _TelemetryGrid({required this.snapshot});

  final LocationSocketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final location = snapshot.latestLocation;

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
            _TelemetryCard(
              icon: Icons.speed_rounded,
              label: "Speed",
              value: location?.speedKmh.toString() ?? "--",
              unit: "km/h",
            ),
            _TelemetryCard(
              icon: Icons.my_location_rounded,
              label: "Accuracy",
              value: location?.accuracy.toString() ?? "--",
              unit: "m",
            ),
            _TelemetryCard(
              icon: Icons.explore_rounded,
              label: "Heading",
              value: location?.heading.toString() ?? "--",
              unit: "deg",
            ),
            _TelemetryCard(
              icon: Icons.upload_rounded,
              label: "Packets",
              value: snapshot.recentPackets.length.toString(),
              unit: "sent",
            ),
          ],
        );
      },
    );
  }
}

class _CreateTripPanel extends StatelessWidget {
  const _CreateTripPanel({required this.snapshot});

  final LocationSocketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconTile(
                icon: Icons.add_road_rounded,
                color: Color(0xffF4A261),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  "Create or share a trip",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff102A43),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Your live GPS stream is joined to this trip room. Share the room id with your backend tester or trip members.",
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackActions = constraints.maxWidth < 330;
              final createButton = FilledButton.icon(
                onPressed: () {},
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
              );
              final shareButton = IconButton.filledTonal(
                onPressed: () {},
                tooltip: "Share trip code",
                icon: const Icon(Icons.ios_share_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xffE8F3F2),
                  foregroundColor: const Color(0xff006D77),
                  fixedSize: const Size(50, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );

              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    createButton,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: shareButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: createButton),
                  const SizedBox(width: 12),
                  shareButton,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xffF7FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.vpn_key_rounded,
                  color: Colors.blueGrey.shade500,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Room id",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xff526A78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    snapshot.roomId,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xff102A43),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.members});

  final List<_TripMember> members;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: "Trip friends",
            action: "${members.length} total",
          ),
          const SizedBox(height: 14),
          for (final member in members) ...[
            _MemberRow(member: member),
            if (member != members.last) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _GpsPacketsPanel extends StatelessWidget {
  const _GpsPacketsPanel({required this.packets});

  final List<LocationTelemetry> packets;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: "Recent GPS packets", action: "websocket"),
          const SizedBox(height: 14),
          for (final packet in packets) ...[
            _PacketRow(packet: packet),
            if (packet != packets.last) const SizedBox(height: 12),
          ],
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
            color: const Color(0xff102A43).withOpacity(.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
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
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
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
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white.withOpacity(.14);
    final bdColor = borderColor ?? Colors.white.withOpacity(.18);
    final fgColor = textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bdColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xffE4F8F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Color(0xff2A9D8F), size: 8),
          SizedBox(width: 6),
          Text(
            "LIVE",
            style: TextStyle(
              color: Color(0xff1D7E73),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.86),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xff102A43),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RanchiMapView extends StatelessWidget {
  const _RanchiMapView();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            const Positioned.fill(child: _OpenStreetMapTiles()),
            Positioned.fill(
              child: Container(color: Colors.white.withOpacity(.08)),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _MapRoutePainter()),
            ),
            const Positioned(
              left: 82,
              top: 88,
              child: _MapMarker(
                label: "You",
                color: Color(0xff006D77),
                icon: Icons.my_location_rounded,
              ),
            ),
            const Positioned(
              left: 36,
              top: 72,
              child: _MapMarker(
                label: "Start",
                color: Color(0xff102A43),
                icon: Icons.location_on_rounded,
              ),
            ),
            const Positioned(
              right: 38,
              top: 58,
              child: _MapMarker(
                label: "Trip",
                color: Color(0xffF4A261),
                icon: Icons.flag_rounded,
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _MapChip(
                icon: Icons.map_rounded,
                label: "OpenStreetMap",
                color: const Color(0xff102A43).withOpacity(.86),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _MapChip(
                icon: Icons.sensors_rounded,
                label: "Live GPS",
                color: const Color(0xff006D77).withOpacity(.92),
              ),
            ),
            const Positioned(right: 10, bottom: 76, child: _MapAttribution()),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 14,
              child: Row(
                children: [
                  Expanded(
                    child: _MiniMetric(label: "Distance", value: "5.8 km"),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(label: "ETA", value: "18 min"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenStreetMapTiles extends StatelessWidget {
  const _OpenStreetMapTiles();

  static const _zoom = 15;
  static const _centerX = 24149;
  static const _centerY = 14197;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = constraints.maxWidth / 2.35;
        final centerLeft = (constraints.maxWidth - tileSize) / 2;
        final centerTop = (constraints.maxHeight - tileSize) / 2;

        return Stack(
          children: [
            for (var dx = -1; dx <= 1; dx++)
              for (var dy = -1; dy <= 1; dy++)
                Positioned(
                  left: centerLeft + dx * tileSize,
                  top: centerTop + dy * tileSize,
                  width: tileSize,
                  height: tileSize,
                  child: Image.network(
                    "https://tile.openstreetmap.org/$_zoom/"
                    "${_centerX + dx}/${_centerY + dy}.png",
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xffDDEDEB),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.map_outlined,
                          color: Colors.blueGrey.shade300,
                        ),
                      );
                    },
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  const _MapRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final routeBase = Paint()
      ..color = Colors.white.withOpacity(.72)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final route = Paint()
      ..color = const Color(0xff006D77)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .16, size.height * .43)
      ..cubicTo(
        size.width * .30,
        size.height * .36,
        size.width * .42,
        size.height * .55,
        size.width * .56,
        size.height * .47,
      )
      ..cubicTo(
        size.width * .66,
        size.height * .40,
        size.width * .76,
        size.height * .36,
        size.width * .86,
        size.height * .34,
      );
    canvas.drawPath(path, routeBase);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "© OpenStreetMap",
        style: TextStyle(
          color: Colors.blueGrey.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final _TripMember member;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: member.color.withOpacity(.16),
          child: Text(
            member.name.substring(0, 1),
            style: TextStyle(color: member.color, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff102A43),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                member.role,
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(
            member.status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: member.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PacketRow extends StatelessWidget {
  const _PacketRow({required this.packet});

  final LocationTelemetry packet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xffF7FAFB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.data_object_rounded,
            color: Color(0xff006D77),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${packet.latitude.toStringAsFixed(6)}, "
                  "${packet.longitude.toStringAsFixed(6)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff102A43),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${packet.speedKmh} km/h",
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 52),
            child: Text(
              _timeLabel(packet.recordedAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.blueGrey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime recordedAt) {
    final age = DateTime.now().toUtc().difference(recordedAt);

    if (age.inSeconds < 5) return "Now";
    if (age.inSeconds < 60) return "${age.inSeconds}s";
    if (age.inMinutes < 60) return "${age.inMinutes}m";

    return "${age.inHours}h";
  }
}

class _TripMember {
  const _TripMember(this.name, this.role, this.status, this.color);

  final String name;
  final String role;
  final String status;
  final Color color;
}
