import "dart:async";

import "package:dio/dio.dart";

import "error_messages.dart";

/// Base URL comes from --dart-define (PROJECT.md §4):
/// emulator → `http://10.0.2.2:3000` · phone → `http://<LAN-IP>:3000`
const String apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "http://10.0.2.2:3000",
);

/// Server answered with success:false (or the request never reached it).
class ApiException implements Exception {
  final String code;
  final String message;

  ApiException(this.code, this.message);

  @override
  String toString() => "$code: $message";
}

/// Typed outcome of an API call — never throws for business errors.
class ApiResult<T> {
  const ApiResult.ok(this.data)
      : code = null,
        message = null;

  const ApiResult.err(this.code, this.message) : data = null;

  final T? data;
  final String? code;
  final String? message;

  bool get isOk => code == null;
}

class ApiClient {
  /// Returns the persisted session JWT, or null when logged out. Re-read per
  /// request so login/logout take effect immediately (§5: Bearer everywhere).
  ApiClient({Dio? dio, this.tokenProvider}) : _dio = dio ?? Dio(_baseOptions()) {
    _dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final body = response.data;
          if (body is Map<String, dynamic>) {
            if (body["success"] != true) {
              final error = body["error"] as Map<String, dynamic>?;
              handler.reject(DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: ApiException(
                  (error?["code"] ?? "INTERNAL") as String,
                  (error?["message"] ?? "Unexpected server response") as String,
                ),
              ));
              return;
            }
            // unwrap the §4 envelope — callers see `data` directly
            response.data = body["data"];
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final inner = error.error;
          if (inner is ApiException) return handler.reject(error);
          // timeout / connection refused / no route to host …
          handler.next(error);
        },
      ),
    ]);
  }

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (_) => true, // envelope decides success
      );

  final Dio _dio;

  /// Session token source — null provider or null token sends no header.
  final String? Function()? tokenProvider;

  Future<ApiResult<T>> _send<T>(
    String method,
    String path, {
    Object? body,
    T Function(dynamic json)? parse,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      final json = response.data;
      if (parse != null) return ApiResult.ok(parse(json));
      return ApiResult.ok(json as T);
    } on ApiException catch (e) {
      return ApiResult.err(e.code, errorMessageFor(e.code, serverMessage: e.message));
    } on DioException catch (e) {
      // interceptor rejections wrap ApiException inside the DioException
      final inner = e.error;
      if (inner is ApiException) {
        return ApiResult.err(
          inner.code,
          errorMessageFor(inner.code, serverMessage: inner.message),
        );
      }
      // timeout / connection refused / no route to host …
      return ApiResult.err("NETWORK", errorMessageFor("NETWORK"));
    }
  }

  Future<ApiResult<T>> get<T>(String path, {T Function(dynamic)? parse}) =>
      _send<T>("GET", path, parse: parse);

  Future<ApiResult<T>> post<T>(String path,
          {Object? body, T Function(dynamic)? parse}) =>
      _send<T>("POST", path, body: body, parse: parse);

  Future<ApiResult<T>> patch<T>(String path,
          {Object? body, T Function(dynamic)? parse}) =>
      _send<T>("PATCH", path, body: body, parse: parse);

  /// POST a multipart/form-data [body] (avatar uploads). Rides the same
  /// interceptor stack — bearer header + §4 envelope unwrap — as every verb.
  Future<ApiResult<T>> postMultipart<T>(
    String path, {
    required FormData body,
    T Function(dynamic)? parse,
  }) =>
      _send<T>("POST", path, body: body, parse: parse);
}
