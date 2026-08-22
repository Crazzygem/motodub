import "../models/driver.dart";
import "api_client.dart";

/// All driver endpoints from the §4 contract. Widgets never see HTTP (§12).
class DriverRepo {
  const DriverRepo(this._client);

  final ApiClient _client;

  /// Own vehicle profile (Task 4.6) — `NOT_FOUND` before first-time setup.
  Future<ApiResult<Driver>> me() =>
      _client.get<Driver>("/api/drivers/me", parse: Driver.fromJson);

  /// Swipe-deck source (§8): verified + online + fresh + not busy,
  /// ≤ 10 km, sorted by distance, top 20. Returns deck cards.
  Future<ApiResult<List<Driver>>> nearby({
    required double lat,
    required double lng,
  }) =>
      _client.get<List<Driver>>(
        "/api/drivers/nearby?lat=$lat&lng=$lng",
        parse: (json) => [
          for (final row in json as List<dynamic>) Driver.fromJson(row),
        ],
      );

  /// Create the one vehicle profile for the signed-in driver (`verified=false`).
  Future<ApiResult<Driver>> createVehicle({
    required String carModel,
    required String plate,
    required String licenseNo,
    required double pricePerKm,
  }) =>
      _client.post<Driver>(
        "/api/drivers",
        body: {
          "car_model": carModel,
          "plate": plate,
          "license_no": licenseNo,
          "price_per_km": pricePerKm,
        },
        parse: Driver.fromJson,
      );

  /// Update own vehicle fields — only the provided ones are sent.
  Future<ApiResult<Driver>> updateVehicle({
    String? carModel,
    String? plate,
    String? licenseNo,
    double? pricePerKm,
  }) =>
      _client.patch<Driver>(
        "/api/drivers",
        body: {
          "car_model": ?carModel,
          "plate": ?plate,
          "license_no": ?licenseNo,
          "price_per_km": ?pricePerKm,
        },
        parse: Driver.fromJson,
      );

  /// Online toggle; bumps `updated_at` server-side and sets lat/lng when
  /// the driver shares a location fix with the request.
  Future<ApiResult<Driver>> setOnline(bool online, {double? lat, double? lng}) =>
      _client.patch<Driver>(
        "/api/drivers/online",
        body: {
          "online": online,
          "lat": ?lat,
          "lng": ?lng,
        },
        parse: Driver.fromJson,
      );
}
