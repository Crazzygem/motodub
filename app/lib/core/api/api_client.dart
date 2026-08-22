import "dart:async";

import "package:dio/dio.dart";

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
  ApiClient({Dio? dio}) : _dio = dio ?? Dio(_baseOptions()) {
    _dio.interceptors.addAll([
      InterceptorsWrapper(
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
      return ApiResult.err(e.code, e.message);
    } on DioException catch (e) {
      // interceptor rejections wrap ApiException inside the DioException
      final inner = e.error;
      if (inner is ApiException) return ApiResult.err(inner.code, inner.message);
      return ApiResult.err(
        "NETWORK",
        "Cannot reach server. Is the backend running?",
      );
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
}
