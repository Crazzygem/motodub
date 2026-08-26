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

/// Seth directive — GET /api/admin/bots/status snapshot. Wire keys are
/// camelCase per that contract's documented deviation; [lastRideAt] is an
/// ISO-8601 string or null before the first spawned ride. Every field but
/// [running] tolerates absence so DELETE /api/admin/bots' bare
/// `{running:false}` parses through the same shape.
class BotsStatus {
  const BotsStatus({
    required this.running,
    this.ridesSpawned = 0,
    this.uptimeSec = 0,
    this.lastRideAt,
  });

  final bool running;
  final int ridesSpawned;
  final int uptimeSec;

  /// ISO-8601 timestamp of the most recent bot-spawned ride, null when none.
  final String? lastRideAt;

  static BotsStatus fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return BotsStatus(
      running: (map["running"] as bool?) ?? false,
      ridesSpawned: (map["ridesSpawned"] as int?) ?? 0,
      uptimeSec: (map["uptimeSec"] as int?) ?? 0,
      lastRideAt: map["lastRideAt"] as String?,
    );
  }
}

/// One row of GET /api/admin/drivers — the verification-table wire shape.
/// Id semantics are explicit server-side (Task 6.1): [driverId] is the
/// drivers-row PK (what /admin/drivers/:id/* address); [userId] is users.id.
/// Task 6.3 adds vehicle identity + last heartbeat position ([lat]/[lng]
/// are null until a driver reports one) for the live map. The admin list
/// carries no license_no today, so [licenseNo] stays null until the PATCH
/// echo includes it — the edit sheet starts blank in that case.
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
    this.carModel,
    this.plate,
    this.licenseNo,
    this.lat,
    this.lng,
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
  final String? carModel;
  final String? plate;
  final String? licenseNo;
  final double? lat;
  final double? lng;

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
      carModel: map["car_model"] as String?,
      plate: map["plate"] as String?,
      licenseNo: map["license_no"] as String?,
      lat: _asDoubleOrNull(map["lat"]),
      lng: _asDoubleOrNull(map["lng"]),
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

  /// Seth directive — deploy [count] bot customer/driver pairs. Conflicts
  /// with a running manager surface as BOT_ALREADY_RUNNING through the
  /// envelope (documented server choice), not an exception.
  Future<ApiResult<BotsStatus>> startBots(int count) => _client.post<BotsStatus>(
        "/api/admin/bots",
        body: {"count": count},
        parse: BotsStatus.fromJson,
      );

  /// Stop the bot manager (offlines its drivers, closes their sockets).
  Future<ApiResult<BotsStatus>> stopBots() =>
      _client.delete<BotsStatus>("/api/admin/bots", parse: BotsStatus.fromJson);

  /// Manual-refresh snapshot of the manager (running flag + counters).
  Future<ApiResult<BotsStatus>> botsStatus() =>
      _client.get<BotsStatus>("/api/admin/bots/status", parse: BotsStatus.fromJson);

  /// Edit any driver "just like the driver side" — [fields] carries the
  /// snake_case wire keys the route validates (name, phone, car_model,
  /// plate, license_no, price_per_km); the response is the fresh row.
  Future<ApiResult<AdminDriver>> patchDriver(
    int driverRowId,
    Map<String, dynamic> fields,
  ) =>
      _client.patch<AdminDriver>(
        "/api/admin/drivers/$driverRowId",
        body: fields,
        parse: AdminDriver.fromJson,
      );
}
