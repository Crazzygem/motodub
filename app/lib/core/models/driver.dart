/// App-side mirror of the `drivers` table (ARCHITECTURE §10), extended with
/// the optional fields `GET /api/drivers/nearby` adds to each deck card
/// (name, photo, rating, distance_km, eta_minutes).
class Driver {
  const Driver({
    required this.id,
    required this.userId,
    required this.carModel,
    required this.plate,
    required this.licenseNo,
    required this.verified,
    required this.online,
    required this.pricePerKm,
    this.lat,
    this.lng,
    this.updatedAt,
    this.name,
    this.photo,
    this.rating,
    this.distanceKm,
    this.etaMinutes,
    this.vehiclePhoto,
    this.vehiclePhotos = const [],
  });

  final int id;
  final int userId;
  final String carModel;
  final String plate;
  final String licenseNo;
  final bool verified;
  final bool online;
  final double pricePerKm; // asking-rate hint only — never a fare (§8/§9)
  final double? lat;
  final double? lng;
  final DateTime? updatedAt; // location heartbeat column (§6 freshness)
  // nearby deck-card extras — null outside the swipe-deck payload
  final String? name;
  final String? photo;
  final double? rating;
  final double? distanceKm;
  final int? etaMinutes;
  // Vehicle photo URL (drivers.vehicle_photo) — set on deck cards, own
  // profile and admin rows; null when the driver never uploaded one.
  final String? vehiclePhoto;
  // Multi-photo gallery (drivers.vehicle_photos JSON array) — the tinder-style
  // pager source; [] when the driver has no gallery.
  final List<String> vehiclePhotos;

  /// Gallery the card/grid should show: the server-normalized array, or the
  /// legacy single cover when only `vehicle_photo` is populated.
  List<String> get effectiveVehiclePhotos {
    if (vehiclePhotos.isNotEmpty) return vehiclePhotos;
    final cover = vehiclePhoto?.trim();
    return (cover == null || cover.isEmpty) ? const [] : [cover];
  }

  static Driver fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Driver(
      id: map["id"] as int,
      userId: map["user_id"] as int? ?? 0,
      carModel: (map["car_model"] as String?) ?? "",
      plate: (map["plate"] as String?) ?? "",
      licenseNo: (map["license_no"] as String?) ?? "",
      verified: (map["verified"] as bool?) ?? false,
      online: (map["online"] as bool?) ?? false,
      pricePerKm: _asDouble(map["price_per_km"]),
      lat: _asDoubleOrNull(map["lat"]),
      lng: _asDoubleOrNull(map["lng"]),
      updatedAt: _asDateOrNull(map["updated_at"]),
      name: map["name"] as String?,
      photo: map["photo"] as String?,
      rating: _asDoubleOrNull(map["rating"]),
      distanceKm: _asDoubleOrNull(map["distance_km"]),
      etaMinutes: map["eta_minutes"] as int?,
      vehiclePhoto: map["vehicle_photo"] as String?,
      vehiclePhotos: _asPhotoList(map["vehicle_photos"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        if (userId != 0) "user_id": userId,
        "car_model": carModel,
        "plate": plate,
        "license_no": licenseNo,
        "verified": verified,
        "online": online,
        "price_per_km": pricePerKm,
        "lat": lat,
        "lng": lng,
        if (updatedAt != null)
          "updated_at": updatedAt!.toIso8601String(),
        if (name != null) "name": name,
        if (photo != null) "photo": photo,
        if (rating != null) "rating": rating,
        if (distanceKm != null) "distance_km": distanceKm,
        if (etaMinutes != null) "eta_minutes": etaMinutes,
        if (vehiclePhoto != null) "vehicle_photo": vehiclePhoto,
        if (vehiclePhotos.isNotEmpty) "vehicle_photos": vehiclePhotos,
      };

  static List<String> _asPhotoList(dynamic value) {
    if (value is! List) return const [];
    return [for (final entry in value) if (entry is String) entry];
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.parse(value as String);
  }

  static double? _asDoubleOrNull(dynamic value) =>
      value == null ? null : _asDouble(value);

  static DateTime? _asDateOrNull(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}
