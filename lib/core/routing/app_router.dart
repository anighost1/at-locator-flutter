import 'package:go_router/go_router.dart';

import 'package:atlocator/features/auth/presentation/login_screen.dart';
import 'package:atlocator/features/dashboard/presentation/dashboard_screen.dart';
import 'package:atlocator/features/history/presentation/history_screen.dart';
import 'package:atlocator/features/home/presentation/home_screen.dart';
import 'package:atlocator/features/map/presentation/map_screen.dart';
import 'package:atlocator/features/profile/presentation/profile_screen.dart';
import 'package:atlocator/features/splash/presentation/splash_screen.dart';

import 'route_names.dart';

final GoRouter router = GoRouter(
  initialLocation: RouteNames.splash,

  routes: [
    GoRoute(
      path: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),

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
