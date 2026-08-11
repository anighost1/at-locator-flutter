import 'package:atlocator/core/api/api_client.dart';
import 'package:atlocator/core/api/api_endpoints.dart';
import 'package:atlocator/core/api/api_exception.dart';
import 'package:atlocator/features/trip/models/trip_models.dart';

class TripRepository {
  Future<Trip> createTrip(String name) async {
    final json = await ApiClient.post(ApiEndpoints.createTrip, {"name": name});

    return Trip.fromJson(json);
  }

  Future<Trip?> getOngoingTrip() async {
    late final Map<String, dynamic> json;

    try {
      json = await ApiClient.getMap(ApiEndpoints.ongoingTrip);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }

    if (json.isEmpty || json["id"] == null) return null;

    return Trip.fromJson(json);
  }

  Future<List<Trip>> getTrips() async {
    try {
      final json = await ApiClient.getList(ApiEndpoints.trips);
      return json.whereType<Map<String, dynamic>>().map(Trip.fromJson).toList();
    } on ApiException catch (error) {
      if (error.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<Trip> endTrip(int tripId) async {
    final json = await ApiClient.put(ApiEndpoints.endTrip(tripId));

    return Trip.fromJson(json);
  }

  Future<TripSummary?> getSummary(int tripId) async {
    final json = await ApiClient.getList(ApiEndpoints.tripSummary(tripId));
    final summaries = json
        .whereType<Map<String, dynamic>>()
        .map(TripSummary.fromJson)
        .toList();

    if (summaries.isEmpty) return null;

    return summaries.first;
  }
}
