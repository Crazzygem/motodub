import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/driver_repo.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/core/models/user.dart";

/// Routes every request to [handler] and records it — no network, no new deps.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
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

ResponseBody _ok(dynamic data) => ResponseBody.fromString(
      jsonEncode({"success": true, "data": data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

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
  group("User model", () {
    const json = {
      "id": 1,
      "role": "customer",
      "name": "Srey",
      "phone": "+85512200100",
      "email": "srey@taxi.demo",
      "photo": null,
      "rating": "5.0",
      "active": true,
      "fcm_token": "tok_123",
    };

    test("fromJson maps snake_case API fields", () {
      final user = User.fromJson(json);
      expect(user.id, 1);
      expect(user.role, "customer");
      expect(user.name, "Srey");
      expect(user.phone, "+85512200100");
      expect(user.email, "srey@taxi.demo");
      expect(user.photo, isNull);
      expect(user.rating, 5.0);
      expect(user.active, isTrue);
      expect(user.fcmToken, "tok_123");
    });

    test("toJson round-trips through fromJson", () {
      final original = User.fromJson(json);
      final roundTrip = User.fromJson(original.toJson());
      expect(roundTrip.id, original.id);
      expect(roundTrip.role, original.role);
      expect(roundTrip.name, original.name);
      expect(roundTrip.phone, original.phone);
      expect(roundTrip.email, original.email);
      expect(roundTrip.photo, original.photo);
      expect(roundTrip.rating, original.rating);
      expect(roundTrip.active, original.active);
      expect(roundTrip.fcmToken, original.fcmToken);
    });
  });

  group("Driver model", () {
    test("fromJson maps the full drivers-table row", () {
      final driver = Driver.fromJson(const {
        "id": 7,
        "user_id": 4,
        "car_model": "Honda Dream",
        "plate": "PP-1A-2345",
        "license_no": "L-99887",
        "verified": true,
        "online": true,
        "price_per_km": "1.20",
        "lat": "11.5564000",
        "lng": "104.9282000",
        "updated_at": "2026-08-22T10:00:00.000Z",
      });
      expect(driver.id, 7);
      expect(driver.userId, 4);
      expect(driver.carModel, "Honda Dream");
      expect(driver.plate, "PP-1A-2345");
      expect(driver.licenseNo, "L-99887");
      expect(driver.verified, isTrue);
      expect(driver.online, isTrue);
      expect(driver.pricePerKm, 1.20);
      expect(driver.lat, 11.5564);
      expect(driver.lng, 104.9282);
      expect(driver.updatedAt, DateTime.utc(2026, 8, 22, 10));
      expect(driver.name, isNull);
      expect(driver.distanceKm, isNull);
      expect(driver.etaMinutes, isNull);
    });

    test("fromJson accepts the nearby deck-card shape", () {
      final driver = Driver.fromJson(const {
        "id": 7,
        "name": "Dara",
        "photo": null,
        "rating": "4.9",
        "car_model": "Honda Dream",
        "plate": "PP-1A-2345",
        "price_per_km": "1.20",
        "distance_km": 1.4,
        "eta_minutes": 4,
      });
      expect(driver.name, "Dara");
      expect(driver.rating, 4.9);
      expect(driver.distanceKm, 1.4);
      expect(driver.etaMinutes, 4);
      expect(driver.pricePerKm, 1.20);
      expect(driver.verified, isFalse); // absent → default false
    });

    test("toJson round-trips through fromJson", () {
      const json = {
        "id": 7,
        "user_id": 4,
        "car_model": "Honda Dream",
        "plate": "PP-1A-2345",
        "license_no": "L-99887",
        "verified": false,
        "online": false,
        "price_per_km": "0.90",
        "lat": null,
        "lng": null,
        "updated_at": "2026-08-22T10:00:00.000Z",
      };
      final roundTrip = Driver.fromJson(Driver.fromJson(json).toJson());
      expect(roundTrip.carModel, "Honda Dream");
      expect(roundTrip.plate, "PP-1A-2345");
      expect(roundTrip.pricePerKm, 0.90);
      expect(roundTrip.lat, isNull);
      expect(roundTrip.licenseNo, "L-99887");
    });
  });

  group("Ride model", () {
    test("fromJson maps snake_case fields and tolerates DECIMAL strings", () {
      final ride = Ride.fromJson(const {
        "id": 42,
        "customer_id": 1,
        "driver_id": 4,
        "status": "requested",
        "pickup_lat": "11.5564000",
        "pickup_lng": "104.9282000",
        "pickup_address": "Central Market",
        "dropoff_lat": "11.5449000",
        "dropoff_lng": "104.8922000",
        "dropoff_address": "Airport",
        "fare": null,
        "customer_rating": null,
        "driver_rating": null,
        "created_at": "2026-08-22T09:00:00.000Z",
        "updated_at": "2026-08-22T09:00:00.000Z",
      });
      expect(ride.id, 42);
      expect(ride.customerId, 1);
      expect(ride.driverId, 4);
      expect(ride.status, "requested");
      expect(ride.pickupLat, 11.5564);
      expect(ride.pickupLng, 104.9282);
      expect(ride.pickupAddress, "Central Market");
      expect(ride.dropoffLat, 11.5449);
      expect(ride.dropoffLng, 104.8922);
      expect(ride.dropoffAddress, "Airport");
      expect(ride.fare, isNull); // reserved — never set (§9)
      expect(ride.customerRating, isNull);
      expect(ride.driverRating, isNull);
      expect(ride.createdAt, DateTime.utc(2026, 8, 22, 9));
    });

    test("fromJson keeps set ratings and numeric lat/lng", () {
      final ride = Ride.fromJson(const {
        "id": 43,
        "customer_id": 1,
        "driver_id": 4,
        "status": "completed",
        "pickup_lat": 11.5564,
        "pickup_lng": 104.9282,
        "pickup_address": "Central Market",
        "dropoff_lat": 11.5449,
        "dropoff_lng": 104.8922,
        "dropoff_address": "Airport",
        "fare": null,
        "customer_rating": 5,
        "driver_rating": 4,
      });
      expect(ride.customerRating, 5);
      expect(ride.driverRating, 4);
      expect(ride.pickupLat, 11.5564);
    });

    test("toJson round-trips through fromJson", () {
      const json = {
        "id": 44,
        "customer_id": 2,
        "driver_id": 5,
        "status": "en_route",
        "pickup_lat": "11.5000000",
        "pickup_lng": "104.8000000",
        "pickup_address": "Riverside",
        "dropoff_lat": "11.5200000",
        "dropoff_lng": "104.8500000",
        "dropoff_address": "Russian Market",
        "fare": null,
        "customer_rating": null,
        "driver_rating": null,
      };
      final roundTrip = Ride.fromJson(Ride.fromJson(json).toJson());
      expect(roundTrip.status, "en_route");
      expect(roundTrip.customerId, 2);
      expect(roundTrip.pickupAddress, "Riverside");
      expect(roundTrip.dropoffLng, 104.85);
    });
  });

  group("RideRepo", () {
    test("create posts camelCase nested payload to /api/rides", () async {
      late RequestOptions captured;
      final repo = RideRepo(_clientWith((options) {
        captured = options;
        return _ok(const {
          "id": 100,
          "customer_id": 1,
          "driver_id": 4,
          "status": "requested",
          "pickup_lat": 11.5564,
          "pickup_lng": 104.9282,
          "pickup_address": "Central Market",
          "dropoff_lat": 11.5449,
          "dropoff_lng": 104.8922,
          "dropoff_address": "Airport",
        });
      }));

      final result = await repo.create(
        driverId: 4,
        pickupLat: 11.5564,
        pickupLng: 104.9282,
        pickupAddress: "Central Market",
        dropoffLat: 11.5449,
        dropoffLng: 104.8922,
        dropoffAddress: "Airport",
      );

      expect(captured.method, "POST");
      expect(captured.uri.path, "/api/rides");
      expect(captured.data, {
        "driverId": 4,
        "pickup": {
          "lat": 11.5564,
          "lng": 104.9282,
          "address": "Central Market",
        },
        "dropoff": {
          "lat": 11.5449,
          "lng": 104.8922,
          "address": "Airport",
        },
      });
      expect(result.isOk, isTrue);
      expect(result.data!.id, 100);
      expect(result.data!.status, "requested");
    });

    test("state actions post to /api/rides/{id}/{action} and parse Ride",
        () async {
      for (final action in RideAction.values) {
        late RequestOptions captured;
        final repo = RideRepo(_clientWith((options) {
          captured = options;
          return _ok({
            "id": 55,
            "customer_id": 1,
            "driver_id": 4,
            "status": action.wireName == "start" ? "en_route" : "accepted",
            "pickup_lat": 11.5,
            "pickup_lng": 104.9,
            "pickup_address": "a",
            "dropoff_lat": 11.5,
            "dropoff_lng": 104.9,
            "dropoff_address": "b",
          });
        }));

        final result = await repo.act(55, action);

        expect(captured.method, "POST", reason: "action ${action.wireName}");
        expect(captured.uri.path, "/api/rides/55/${action.wireName}",
            reason: "action ${action.wireName}");
        expect(result.isOk, isTrue, reason: "action ${action.wireName}");
        expect(result.data!.id, 55);
      }
    });

    test("rate posts stars to /api/rides/{id}/rate", () async {
      late RequestOptions captured;
      final repo = RideRepo(_clientWith((options) {
        captured = options;
        return _ok(const {
          "id": 56,
          "customer_id": 1,
          "driver_id": 4,
          "status": "completed",
          "pickup_lat": 11.5,
          "pickup_lng": 104.9,
          "pickup_address": "a",
          "dropoff_lat": 11.5,
          "dropoff_lng": 104.9,
          "dropoff_address": "b",
          "customer_rating": 5,
        });
      }));

      final result = await repo.rate(56, stars: 5);

      expect(captured.method, "POST");
      expect(captured.uri.path, "/api/rides/56/rate");
      expect(captured.data, {"stars": 5});
      expect(result.data!.customerRating, 5);
    });

    test("mine gets /api/rides/mine and parses the list", () async {
      late RequestOptions captured;
      final repo = RideRepo(_clientWith((options) {
        captured = options;
        return _ok([
          {
            "id": 61,
            "customer_id": 1,
            "driver_id": 4,
            "status": "completed",
            "pickup_lat": 11.5,
            "pickup_lng": 104.9,
            "pickup_address": "a",
            "dropoff_lat": 11.5,
            "dropoff_lng": 104.9,
            "dropoff_address": "b",
          },
          {
            "id": 62,
            "customer_id": 1,
            "driver_id": 5,
            "status": "cancelled",
            "pickup_lat": 11.5,
            "pickup_lng": 104.9,
            "pickup_address": "a",
            "dropoff_lat": 11.5,
            "dropoff_lng": 104.9,
            "dropoff_address": "b",
          },
        ]);
      }));

      final result = await repo.mine();

      expect(captured.method, "GET");
      expect(captured.uri.path, "/api/rides/mine");
      expect(result.isOk, isTrue);
      expect(result.data!.length, 2);
      expect(result.data![0].status, "completed");
      expect(result.data![1].status, "cancelled");
    });

    test("getById gets /api/rides/{id}", () async {
      late RequestOptions captured;
      final repo = RideRepo(_clientWith((options) {
        captured = options;
        return _ok(const {
          "id": 77,
          "customer_id": 1,
          "driver_id": 4,
          "status": "in_progress",
          "pickup_lat": 11.5,
          "pickup_lng": 104.9,
          "pickup_address": "a",
          "dropoff_lat": 11.5,
          "dropoff_lng": 104.9,
          "dropoff_address": "b",
        });
      }));

      final result = await repo.getById(77);

      expect(captured.method, "GET");
      expect(captured.uri.path, "/api/rides/77");
      expect(result.data!.status, "in_progress");
    });

    test("business error surfaces as ApiResult.err with server code",
        () async {
      final repo = RideRepo(
        _clientWith((_) => _err("RIDE_BUSY_DRIVER", "Driver already has an active ride")),
      );

      final result = await repo.create(
        driverId: 4,
        pickupLat: 11.5,
        pickupLng: 104.9,
        pickupAddress: "a",
        dropoffLat: 11.5,
        dropoffLng: 104.9,
        dropoffAddress: "b",
      );

      expect(result.isOk, isFalse);
      expect(result.code, "RIDE_BUSY_DRIVER");
      // Task 2.4: known codes surface curated friendly copy, not raw server text
      expect(result.message, "This driver is busy right now. Try another one.");
      expect(result.data, isNull);
    });
  });

  group("DriverRepo", () {
    test("nearby queries /api/drivers/nearby with lat/lng and parses cards",
        () async {
      late RequestOptions captured;
      final repo = DriverRepo(_clientWith((options) {
        captured = options;
        return _ok([
          {
            "id": 7,
            "name": "Dara",
            "photo": null,
            "rating": "4.9",
            "car_model": "Honda Dream",
            "plate": "PP-1A-2345",
            "price_per_km": "1.20",
            "distance_km": 1.4,
            "eta_minutes": 4,
          },
        ]);
      }));

      final result = await repo.nearby(lat: 11.5564, lng: 104.9282);

      expect(captured.method, "GET");
      expect(captured.uri.path, "/api/drivers/nearby");
      expect(captured.uri.queryParameters["lat"], "11.5564");
      expect(captured.uri.queryParameters["lng"], "104.9282");
      expect(result.isOk, isTrue);
      expect(result.data!.single.name, "Dara");
      expect(result.data!.single.distanceKm, 1.4);
      expect(result.data!.single.etaMinutes, 4);
    });

    test("createVehicle posts snake_case fields to POST /api/drivers",
        () async {
      late RequestOptions captured;
      final repo = DriverRepo(_clientWith((options) {
        captured = options;
        return _ok(const {
          "id": 9,
          "user_id": 6,
          "car_model": "Honda Dream",
          "plate": "PP-9Z-9999",
          "license_no": "L-11122",
          "verified": false,
          "online": false,
          "price_per_km": "1.50",
        });
      }));

      final result = await repo.createVehicle(
        carModel: "Honda Dream",
        plate: "PP-9Z-9999",
        licenseNo: "L-11122",
        pricePerKm: 1.50,
      );

      expect(captured.method, "POST");
      expect(captured.uri.path, "/api/drivers");
      expect(captured.data, {
        "car_model": "Honda Dream",
        "plate": "PP-9Z-9999",
        "license_no": "L-11122",
        "price_per_km": 1.50,
      });
      expect(result.data!.verified, isFalse);
      expect(result.data!.userId, 6);
    });

    test("updateVehicle patches /api/drivers", () async {
      late RequestOptions captured;
      final repo = DriverRepo(_clientWith((options) {
        captured = options;
        return _ok(const {
          "id": 9,
          "user_id": 6,
          "car_model": "Yamaha Sirius",
          "plate": "PP-9Z-9999",
          "license_no": "L-11122",
          "verified": false,
          "online": true,
          "price_per_km": "1.10",
        });
      }));

      final result = await repo.updateVehicle(
        carModel: "Yamaha Sirius",
        pricePerKm: 1.10,
      );

      expect(captured.method, "PATCH");
      expect(captured.uri.path, "/api/drivers");
      expect(captured.data, {
        "car_model": "Yamaha Sirius",
        "price_per_km": 1.10,
      });
      expect(result.data!.carModel, "Yamaha Sirius");
    });

    test("setOnline patches /api/drivers/online with location when given",
        () async {
      late RequestOptions captured;
      final repo = DriverRepo(_clientWith((options) {
        captured = options;
        return _ok(const {
          "id": 9,
          "user_id": 6,
          "car_model": "Honda Dream",
          "plate": "PP-9Z-9999",
          "license_no": "L-11122",
          "verified": true,
          "online": true,
          "price_per_km": "1.50",
          "lat": "11.5564",
          "lng": "104.9282",
        });
      }));

      final result =
          await repo.setOnline(true, lat: 11.5564, lng: 104.9282);

      expect(captured.method, "PATCH");
      expect(captured.uri.path, "/api/drivers/online");
      expect(captured.data, {
        "online": true,
        "lat": 11.5564,
        "lng": 104.9282,
      });
      expect(result.data!.online, isTrue);
    });

    test("setOnline omits lat/lng when not provided", () async {
      late RequestOptions captured;
      final repo = DriverRepo(
        _clientWith((options) {
          captured = options;
          return _ok(const {
            "id": 9,
            "user_id": 6,
            "car_model": "c",
            "plate": "p",
            "license_no": "l",
            "verified": false,
            "online": false,
            "price_per_km": "1.00",
          });
        }),
      );

      await repo.setOnline(false);

      expect(captured.data, {"online": false});
    });

    test("DRIVER_NOT_VERIFIED surfaces as ApiResult.err", () async {
      final repo = DriverRepo(
        _clientWith((_) => _err("DRIVER_NOT_VERIFIED", "Wait for admin verification")),
      );

      final result = await repo.nearby(lat: 11.5, lng: 104.9);

      expect(result.isOk, isFalse);
      expect(result.code, "DRIVER_NOT_VERIFIED");
    });
  });
}
