import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/profile/profile_screen.dart';

import 'route_names.dart';

final GoRouter router = GoRouter(
  initialLocation: RouteNames.login,

  routes: [
    // Login Screen
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),

    // Bottom Navigation Shell
    ShellRoute(
      builder: (context, state, child) {
        return DashboardScreen(child: child);
      },

      routes: [
        GoRoute(
          path: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),

        GoRoute(
          path: RouteNames.map,
          builder: (context, state) => const MapScreen(),
        ),

        GoRoute(
          path: RouteNames.history,
          builder: (context, state) => const HistoryScreen(),
        ),

        GoRoute(
          path: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
