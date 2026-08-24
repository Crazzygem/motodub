import "dart:typed_data";

import "package:dio/dio.dart" show DioMediaType, FormData, MultipartFile;

import "../models/user.dart";
import "api_client.dart";

/// Own-profile endpoints (Task A contract): PATCH /users/me, multipart
/// avatar upload, password rotation. Widgets never see HTTP (§12).
class UserRepo {
  const UserRepo(this._client);

  final ApiClient _client;

  /// PATCH /users/me — only name/phone; email is immutable server-side.
  /// Answers the updated `User` row for server-truth reconciliation.
  Future<ApiResult<User>> patchMe({
    String? name,
    String? phone,
  }) =>
      _client.patch<User>(
        "/api/users/me",
        body: {
          "name": ?name,
          "phone": ?phone,
        },
        parse: User.fromJson,
      );

  /// POST /users/me/avatar — multipart field `avatar` (jpeg/png/webp ≤5MB
  /// enforced server-side). Answers the updated `User` with its photo URL.
  Future<ApiResult<User>> uploadAvatar({
    required Uint8List bytes,
    String filename = "avatar.jpg",
    String mimeType = "image/jpeg",
  }) {
    final type = mimeType.split("/");
    return _client.postMultipart<User>(
      "/api/users/me/avatar",
      body: FormData.fromMap({
        "avatar": MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType(type.first, type.last),
        ),
      }),
      parse: User.fromJson,
    );
  }

  /// POST /users/me/password — verifies the current secret, then re-hashes.
  /// The token stays valid; the client re-logins with the new secret.
  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _client.post<void>(
        "/api/users/me/password",
        body: {
          "current_password": currentPassword,
          "new_password": newPassword,
        },
        parse: (_) {},
      );
}
