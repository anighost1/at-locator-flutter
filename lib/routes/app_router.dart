import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import 'route_names.dart';

final GoRouter router = GoRouter(
  initialLocation: RouteNames.login,
  routes: [
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
