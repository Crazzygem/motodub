import "../models/ride.dart";
import "api_client.dart";

/// GET /api/admin/stats snapshot — the four dashboard KPIs (Task 6.2 step 1).
/// `avg_rating` is null before anyone has been rated.
class AdminStats {
  const AdminStats({
    required this.requestedNow,
    required this.onlineDrivers,
    required this.completedToday,
    this.avgRating,
  });

  final int requestedNow; // live rides awaiting acceptance
  final int onlineDrivers;
  final int completedToday;
  final double? avgRating;

  static AdminStats fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return AdminStats(
      requestedNow: map["requested_now"] as int,
      onlineDrivers: map["online_drivers"] as int,
      completedToday: map["completed_today"] as int,
      avgRating: _asDoubleOrNull(map["avg_rating"]),
    );
  }
}

/// One row of GET /api/admin/drivers — the verification-table wire shape.
/// Id semantics are explicit server-side (Task 6.1): [driverId] is the
/// drivers-row PK (what /admin/drivers/:id/* address); [userId] is users.id.
class AdminDriver {
  const AdminDriver({
    required this.driverId,
    required this.userId,
    required this.name,
    required this.email,
    required this.rating,
    required this.active,
    required this.pricePerKm,
    required this.verified,
    required this.online,
    this.phone,
  });

  final int driverId;
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final double rating;
  final bool active; // false = suspended (users.active)
  final double pricePerKm; // asking rate — display-only (§8)
  final bool verified;
  final bool online;

  static AdminDriver fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return AdminDriver(
      driverId: map["driver_id"] as int,
      userId: map["user_id"] as int,
      name: map["name"] as String,
      email: map["email"] as String,
      phone: map["phone"] as String?,
      rating: _asDoubleOrNull(map["rating"]) ?? 0,
      active: (map["active"] as bool?) ?? true,
      pricePerKm: _asDoubleOrNull(map["price_per_km"]) ?? 0,
      verified: (map["verified"] as bool?) ?? false,
      online: (map["online"] as bool?) ?? false,
    );
  }
}

double? _asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse("$value");
}

/// All Task 6.1 admin endpoints (§4 contract, admin-only). Widgets never
/// see HTTP (§12).
class AdminRepo {
  const AdminRepo(this._client);

  final ApiClient _client;

  /// KPI snapshot for the dashboard tab.
  Future<ApiResult<AdminStats>> stats() =>
      _client.get<AdminStats>("/api/admin/stats", parse: AdminStats.fromJson);

  /// Every driver with the columns the verification table renders.
  Future<ApiResult<List<AdminDriver>>> drivers() =>
      _client.get<List<AdminDriver>>(
        "/api/admin/drivers",
        parse: (json) => [
          for (final row in json as List<dynamic>) AdminDriver.fromJson(row),
        ],
      );

  /// Full ride feed, newest first; [status] narrows to one state.
  Future<ApiResult<List<Ride>>> rides({String? status}) =>
      _client.get<List<Ride>>(
        "/api/admin/rides${status == null ? "" : "?status=$status"}",
        parse: (json) => [
          for (final row in json as List<dynamic>) Ride.fromJson(row),
        ],
      );

  /// Flip drivers.verified — [driverRowId] is the drivers-row PK.
  Future<ApiResult<AdminDriver>> verifyDriver(int driverRowId) =>
      _client.post<AdminDriver>(
        "/api/admin/drivers/$driverRowId/verify",
        parse: AdminDriver.fromJson,
      );

  /// Bar the account (users.active=false) — [driverRowId] is the PK.
  Future<ApiResult<AdminDriver>> suspendDriver(int driverRowId) =>
      _client.post<AdminDriver>(
        "/api/admin/drivers/$driverRowId/suspend",
        parse: AdminDriver.fromJson,
      );
}
