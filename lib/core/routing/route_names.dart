class RouteNames {
  static const splash = "/";
  static const login = "/login";
  static const home = "/home";
  static const map = '/map';
  static const trip = '/trip';
  static const tripReplay = '/trip/replay/:tripId';
  static const profile = '/profile';

  static String tripReplayPath(String tripId) => '/trip/replay/$tripId';
}
