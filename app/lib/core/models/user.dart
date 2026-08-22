/// App-side mirror of the `users` table (ARCHITECTURE §10).
/// API field names are snake_case; Dart fields are camelCase.
class User {
  const User({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    required this.email,
    required this.rating,
    required this.active,
    this.photo,
    this.fcmToken,
  });

  final int id;
  final String role; // customer | driver | admin
  final String name;
  final String phone;
  final String email;
  final String? photo;
  final double rating;
  final bool active;
  final String? fcmToken;

  static User fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return User(
      id: map["id"] as int,
      role: map["role"] as String,
      name: map["name"] as String,
      phone: map["phone"] as String,
      email: map["email"] as String,
      photo: map["photo"] as String?,
      rating: _asDouble(map["rating"]),
      active: map["active"] as bool,
      fcmToken: map["fcm_token"] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "role": role,
        "name": name,
        "phone": phone,
        "email": email,
        "photo": photo,
        "rating": rating,
        "active": active,
        "fcm_token": fcmToken,
      };

  /// MySQL DECIMAL columns arrive as JSON strings ("5.0") or numbers.
  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.parse(value as String);
  }
}
