import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlocator/core/routing/route_names.dart';
import 'package:atlocator/features/location/location_socket_service.dart';

class DashboardScreen extends StatefulWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(LocationSocketService.instance.start());
  }

  @override
  void dispose() {
    unawaited(LocationSocketService.instance.stop());
    super.dispose();
  }

  int _getIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    switch (location) {
      case RouteNames.home:
        return 0;
      case RouteNames.map:
        return 1;
      case RouteNames.trip:
        return 2;
      case RouteNames.profile:
        return 3;
      default:
        if (location.startsWith('/trip/')) return 2;
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _getIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xffF7FAFB),
      body: _DashboardSafeArea(child: widget.child),
      bottomNavigationBar: _DashboardNavigationBar(
        currentIndex: index,
        onTap: (value) {
          switch (value) {
            case 0:
              context.go(RouteNames.home);
              break;
            case 1:
              context.go(RouteNames.map);
              break;
            case 2:
              context.go(RouteNames.trip);
              break;
            case 3:
              context.go(RouteNames.profile);
              break;
          }
        },
      ),
    );
  }
}

class _DashboardSafeArea extends StatelessWidget {
  const _DashboardSafeArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff102A43),
      child: SafeArea(
        bottom: false,
        child: ColoredBox(color: const Color(0xffF7FAFB), child: child),
      ),
    );
  }
}

class _DashboardNavigationBar extends StatelessWidget {
  const _DashboardNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavigationItem(Icons.home_rounded, 'Home'),
    _NavigationItem(Icons.map_rounded, 'Map'),
    _NavigationItem(Icons.route_rounded, 'Trip'),
    _NavigationItem(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff102A43).withOpacity(.12),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              10,
              14,
              bottomPadding == 0 ? 10 : 0,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _DashboardNavigationItem(
                      item: _items[i],
                      selected: currentIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardNavigationItem extends StatelessWidget {
  const _DashboardNavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xff006D77) : Colors.blueGrey.shade500;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xffE8F3F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: selected ? 25 : 23),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
