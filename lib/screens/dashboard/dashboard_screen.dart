import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  int _getIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    switch (location) {
      case '/home':
        return 0;
      case '/map':
        return 1;
      case '/history':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _getIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xffF7FAFB),
      body: _DashboardSafeArea(child: child),
      bottomNavigationBar: _DashboardNavigationBar(
        currentIndex: index,
        onTap: (value) {
          switch (value) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/map');
              break;
            case 2:
              context.go('/history');
              break;
            case 3:
              context.go('/profile');
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
        child: ColoredBox(
          color: const Color(0xffF7FAFB),
          child: child,
        ),
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
    _NavigationItem(Icons.history_rounded, 'History'),
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
