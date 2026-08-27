import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:duboun/core/api/api_client.dart";
import "package:duboun/core/api/error_messages.dart";

/// Routes every request to [handler] — no network, no new deps.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWith(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(
    BaseOptions(
      baseUrl: "http://test.local",
      validateStatus: (_) => true, // envelope decides success, like the real client
    ),
  )..httpClientAdapter = _FakeAdapter(handler);
  return ApiClient(dio: dio);
}

ResponseBody _err(String code, String message) => ResponseBody.fromString(
      jsonEncode({
        "success": false,
        "error": {"code": code, "message": message},
      }),
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  group("apiErrorMessages table", () {
    test("covers exactly the ARCHITECTURE §4 codes plus NETWORK", () {
      expect(apiErrorMessages.keys.toSet(), {
        "VALIDATION_ERROR",
        "UNAUTHORIZED",
        "FORBIDDEN",
        "NOT_FOUND",
        "RIDE_INVALID_TRANSITION",
        "RIDE_BUSY_DRIVER",
        "RIDE_BUSY_CUSTOMER",
        "DRIVER_NOT_VERIFIED",
        "NETWORK",
      });
    });

    test("every entry is a non-empty message", () {
      for (final entry in apiErrorMessages.entries) {
        expect(entry.value, isNotEmpty, reason: "${entry.key} has empty copy");
      }
    });
  });

  group("errorMessageFor", () {
    test("maps each known code to its friendly message", () {
      expect(
        errorMessageFor("VALIDATION_ERROR"),
        "Please check your details and try again.",
      );
      expect(errorMessageFor("UNAUTHORIZED"), "Please log in again.");
      expect(errorMessageFor("FORBIDDEN"), "You don't have permission to do that.");
      expect(errorMessageFor("NOT_FOUND"), "We couldn't find that.");
      expect(
        errorMessageFor("RIDE_INVALID_TRANSITION"),
        "That ride can't be updated from its current state.",
      );
      expect(
        errorMessageFor("RIDE_BUSY_DRIVER"),
        "This driver is busy right now. Try another one.",
      );
      expect(errorMessageFor("RIDE_BUSY_CUSTOMER"), "You already have an active ride.");
      expect(
        errorMessageFor("DRIVER_NOT_VERIFIED"),
        "Your account isn't verified yet. Please wait for approval.",
      );
    });

    test("maps NETWORK to the reachability hint", () {
      expect(
        errorMessageFor("NETWORK"),
        "Cannot reach server. Is the backend running?",
      );
    });

    test("unknown code falls back to the server message when present", () {
      expect(
        errorMessageFor("FUTURE_CODE", serverMessage: "Server explains it"),
        "Server explains it",
      );
    });

    test("unknown code without server detail gets the generic fallback", () {
      expect(
        errorMessageFor("FUTURE_CODE"),
        "Something went wrong. Please try again.",
      );
      expect(
        errorMessageFor("FUTURE_CODE", serverMessage: ""),
        "Something went wrong. Please try again.",
      );
    });
  });

  group("ApiClient flow-through", () {
    test("envelope error code comes back as friendly copy", () async {
      final client = _clientWith(
        (_) => _err("RIDE_BUSY_DRIVER", "Driver already has an active ride"),
      );

      final result = await client.get<dynamic>("/api/rides/1");

      expect(result.isOk, isFalse);
      expect(result.code, "RIDE_BUSY_DRIVER");
      expect(result.message, "This driver is busy right now. Try another one.");
    });

    test("unknown envelope code passes the server message through", () async {
      final client = _clientWith((_) => _err("FUTURE_CODE", "Explain later"));

      final result = await client.get<dynamic>("/api/rides/1");

      expect(result.isOk, isFalse);
      expect(result.code, "FUTURE_CODE");
      expect(result.message, "Explain later");
    });

    test("connect timeout maps to the reachability hint", () async {
      final client = _clientWith(
        (options) => throw DioException.connectionTimeout(
          requestOptions: options,
          timeout: const Duration(seconds: 5),
        ),
      );

      final result = await client.get<dynamic>("/api/drivers/nearby?lat=11&lng=104");

      expect(result.isOk, isFalse);
      expect(result.code, "NETWORK");
      expect(result.message, "Cannot reach server. Is the backend running?");
    });

    test("connection refused maps to the reachability hint", () async {
      final client = _clientWith(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: "Connection refused",
        ),
      );

      final result = await client.get<dynamic>("/api/drivers/nearby?lat=11&lng=104");

      expect(result.isOk, isFalse);
      expect(result.code, "NETWORK");
      expect(result.message, "Cannot reach server. Is the backend running?");
    });
  });
}
