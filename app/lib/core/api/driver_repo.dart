import "dart:typed_data";

import "package:dio/dio.dart" show DioMediaType, FormData, MultipartFile;
import "package:image_picker/image_picker.dart" show XFile;

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

  /// POST /drivers/vehicle-photo — multipart field `photo` (jpeg/png/webp
  /// ≤5MB enforced server-side). Answers the updated `Driver` row.
  Future<ApiResult<Driver>> updateVehiclePhoto({
    required Uint8List bytes,
    String filename = "vehicle.jpg",
    String mimeType = "image/jpeg",
  }) {
    final type = mimeType.split("/");
    return _client.postMultipart<Driver>(
      "/api/drivers/vehicle-photo",
      body: FormData.fromMap({
        "photo": MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType(type.first, type.last),
        ),
      }),
      parse: Driver.fromJson,
    );
  }

  /// POST /drivers/photos — multi-photo gallery upload; every file rides the
  /// multipart under field `photos` (server appends, caps at 6 total) and the
  /// updated `Driver` row (gallery + cover) comes back.
  Future<ApiResult<Driver>> uploadPhotos(List<XFile> photos) async {
    final form = FormData();
    for (final photo in photos) {
      final mimeType = photo.mimeType ?? _mimeFromName(photo.name);
      final type = mimeType.split("/");
      form.files.add(MapEntry(
        "photos",
        MultipartFile.fromBytes(
          await photo.readAsBytes(),
          filename: photo.name.isNotEmpty ? photo.name : "vehicle.jpg",
          contentType: DioMediaType(type.first, type.last),
        ),
      ));
    }
    return _client.postMultipart<Driver>(
      "/api/drivers/photos",
      body: form,
      parse: Driver.fromJson,
    );
  }

  /// DELETE /drivers/photos — drops the gallery photo at [index]; answers
  /// the updated `Driver` row.
  Future<ApiResult<Driver>> removePhoto(int index) => _client.delete<Driver>(
        "/api/drivers/photos",
        body: {"index": index},
        parse: Driver.fromJson,
      );
}

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}
