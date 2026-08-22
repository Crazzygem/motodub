import "../models/ride.dart";
import "api_client.dart";

/// Ride state-machine triggers — wire names are the URL segments (§2).
enum RideAction {
  accept("accept"),
  decline("decline"),
  start("start"),
  startRide("start-ride"),
  complete("complete"),
  cancel("cancel");

  const RideAction(this.wireName);

  final String wireName;
}

/// All ride endpoints from the §4 contract. Widgets never see HTTP (§12).
class RideRepo {
  const RideRepo(this._client);

  final ApiClient _client;

  /// Customer books a driver → `requested`. Request body is camelCase per
  /// the booking-sheet contract (`{driverId, pickup{lat,lng,address}, …}`).
  Future<ApiResult<Ride>> create({
    required int driverId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
  }) =>
      _client.post<Ride>(
        "/api/rides",
        body: {
          "driverId": driverId,
          "pickup": {
            "lat": pickupLat,
            "lng": pickupLng,
            "address": pickupAddress,
          },
          "dropoff": {
            "lat": dropoffLat,
            "lng": dropoffLng,
            "address": dropoffAddress,
          },
        },
        parse: Ride.fromJson,
      );

  Future<ApiResult<Ride>> getById(int id) =>
      _client.get<Ride>("/api/rides/$id", parse: Ride.fromJson);

  /// Per-role history view (server picks the rows by JWT role).
  Future<ApiResult<List<Ride>>> mine() => _client.get<List<Ride>>(
        "/api/rides/mine",
        parse: (json) => [
          for (final row in json as List<dynamic>) Ride.fromJson(row),
        ],
      );

  Future<ApiResult<Ride>> act(int id, RideAction action) =>
      _client.post<Ride>(
        "/api/rides/$id/${action.wireName}",
        parse: Ride.fromJson,
      );

  /// Ratings only on `completed` rides, once per participant (§2 invariant 4).
  Future<ApiResult<Ride>> rate(int id, {required int stars}) =>
      _client.post<Ride>(
        "/api/rides/$id/rate",
        body: {"stars": stars},
        parse: Ride.fromJson,
      );
}
