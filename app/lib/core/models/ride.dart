/// App-side mirror of the `rides` table (ARCHITECTURE §10).
/// `fare` stays null in v1 — reserved column, never set (§9).
class Ride {
  const Ride({
    required this.id,
    required this.customerId,
    required this.driverId,
    required this.status,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    this.fare,
    this.customerRating,
    this.driverRating,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerAvgRating,
    this.driverName,
    this.driverPhone,
    this.driverCarModel,
    this.driverPlate,
  });

  final int id;
  final int customerId;
  final int driverId;
  final String status; // requested|accepted|declined|en_route|in_progress|completed|cancelled
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final double? fare; // reserved — NEVER set
  final int? customerRating;
  final int? driverRating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Customer-summary extras from GET /api/rides/{id} (Task 4.6 request
  // card) — null on rows fetched without the eager-loaded summary.
  // Distinct from [customerRating], which is this ride's rating COLUMN.
  final String? customerName;
  final double? customerAvgRating;
  // Driver snapshot from GET /api/rides/{id} (Task 5.1 tracking card) —
  // car/plate come off drivers, name/phone off users; null when absent.
  final String? driverName;
  final String? driverPhone;
  final String? driverCarModel;
  final String? driverPlate;

  static Ride fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Ride(
      id: map["id"] as int,
      customerId: map["customer_id"] as int,
      driverId: map["driver_id"] as int,
      status: map["status"] as String,
      pickupLat: _asDouble(map["pickup_lat"]),
      pickupLng: _asDouble(map["pickup_lng"]),
      pickupAddress: map["pickup_address"] as String,
      dropoffLat: _asDouble(map["dropoff_lat"]),
      dropoffLng: _asDouble(map["dropoff_lng"]),
      dropoffAddress: map["dropoff_address"] as String,
      fare: _asDoubleOrNull(map["fare"]),
      customerRating: map["customer_rating"] as int?,
      driverRating: map["driver_rating"] as int?,
      createdAt: _asDateOrNull(map["created_at"]),
      updatedAt: _asDateOrNull(map["updated_at"]),
      customerName: (map["customer"] as Map<String, dynamic>?)?["name"] as String?,
      customerAvgRating:
          _asDoubleOrNull((map["customer"] as Map<String, dynamic>?)?["rating"]),
      driverName: _driverString(map, "name"),
      driverPhone: _driverString(map, "phone"),
      driverCarModel: _driverString(map, "car_model"),
      driverPlate: _driverString(map, "plate"),
    );
  }

  static String? _driverString(Map<String, dynamic> map, String key) =>
      (map["driver"] as Map<String, dynamic>?)?[key] as String?;

  Map<String, dynamic> toJson() => {
        "id": id,
        "customer_id": customerId,
        "driver_id": driverId,
        "status": status,
        "pickup_lat": pickupLat,
        "pickup_lng": pickupLng,
        "pickup_address": pickupAddress,
        "dropoff_lat": dropoffLat,
        "dropoff_lng": dropoffLng,
        "dropoff_address": dropoffAddress,
        "fare": fare,
        "customer_rating": customerRating,
        "driver_rating": driverRating,
        if (createdAt != null) "created_at": createdAt!.toIso8601String(),
        if (updatedAt != null) "updated_at": updatedAt!.toIso8601String(),
      };

  /// MySQL DECIMAL columns arrive as JSON strings ("11.5564") or numbers.
  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.parse(value as String);
  }

  static double? _asDoubleOrNull(dynamic value) =>
      value == null ? null : _asDouble(value);

  static DateTime? _asDateOrNull(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}
