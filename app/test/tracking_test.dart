import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/api/socket_client.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/features/booking/booking_provider.dart"
    show rideRepoProvider;
import "package:motodub/features/driver/driver_provider.dart"
    show socketClientProvider;
import "package:motodub/features/driver/request_card.dart"
    show etaMinutesForKm, haversineKm;
import "package:motodub/features/tracking/tracking_provider.dart";
import "package:motodub/features/tracking/tracking_screen.dart";

// Task 5.1 — customer tracking: REST boot + socket merges (§6), gated
// cancel, live driver marker, stepper rendering, completed → rating stub.
//
// Isolation: repos subclass the real ones over a dead Dio client; the
// socket is a no-network double fed through the public handleEvent seam
// (same convention as driver_home_test / booking_sheet_test).
const _tileLayer = SizedBox.shrink();

Ride _ride(String status) => Ride(
      id: 100,
      customerId: 9,
      driverId: 40,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
    );

Ride _rideWith(String status) => Ride(
      id: 100,
      customerId: 9,
      driverId: 40,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
      driverName: "Dara",
      driverPhone: "+855 333 333",
      driverCarModel: "Toyota Highlander SUV",
      driverPlate: "PP-1A-2345",
    );

Ride _rideWithPhotos(String status) => Ride(
      id: 100,
      customerId: 9,
      driverId: 40,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
      driverName: "Dara",
      driverPhone: "+855 333 333",
      driverCarModel: "Toyota Highlander SUV",
      driverPlate: "PP-1A-2345",
      driverPhoto: "/uploads/face.jpg",
      driverVehiclePhoto: "/uploads/bike.webp",
    );

ApiResult<Ride> _ok(Ride ride) => ApiResult.ok(ride);

ApiClient _deadClient() => ApiClient(dio: Dio());

/// Serves canned getById results and records every action dispatch.
class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(_deadClient());

  ApiResult<Ride>? getByIdResult;
  ApiResult<Ride>? actResult;

  final List<(int, RideAction)> actCalls = <(int, RideAction)>[];

  @override
  Future<ApiResult<Ride>> getById(int id) async =>
      getByIdResult ?? _ok(_ride("requested"));

  @override
  Future<ApiResult<Ride>> act(int id, RideAction action) async {
    actCalls.add((id, action));
    return actResult ?? _ok(_ride("cancelled"));
  }
}

/// No-network socket double: records joins/writes, replays typed events
/// through the real handleEvent parsing seam.
class _FakeSocket extends SocketClient {
  _FakeSocket() : super(baseUrl: "http://127.0.0.1:1", token: "jwt");

  final List<int> locationJoins = <int>[];
  int connectCalls = 0;

  @override
  void connect() => connectCalls++;

  @override
  void joinLocationRoom(int driverId) => locationJoins.add(driverId);

  void receive(String event, Map<String, dynamic> payload) =>
      handleEvent(event, payload);
}

void main() {
  group("trackingProvider", () {
    late _StubRideRepo repo;
    late _FakeSocket socket;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          rideRepoProvider.overrideWithValue(repo),
          socketClientProvider.overrideWithValue(socket),
        ],
      );
      // Keep-alive subscription: autoDispose providers die with zero
      // listeners, which would cancel the boot before it lands.
      c.listen(trackingProvider(100), (_, _) {});
      return c;
    }

    setUp(() {
      repo = _StubRideRepo();
      socket = _FakeSocket();
    });

    test("boots the ride from REST (loading → loaded)", () async {
      repo.getByIdResult = _ok(_rideWith("requested"));
      final c = container();
      addTearDown(c.dispose);

      expect(c.read(trackingProvider(100)), const TrackingState(loading: true));

      c.read(trackingProvider(100).notifier); // triggers build()
      await c.pump();

      expect(socket.connectCalls, isNot(0)); // socket session opened
      expect(c.read(trackingProvider(100)).ride?.status, "requested");
      expect(c.read(trackingProvider(100)).loading, false);
    });

    test("surfaces mapped errors when the fetch fails", () async {
      repo.getByIdResult =
          const ApiResult.err("NOT_FOUND", "We couldn't find that.");
      final c = container();
      addTearDown(c.dispose);

      c.read(trackingProvider(100).notifier);
      await c.pump();

      final state = c.read(trackingProvider(100));
      expect(state.loading, false);
      expect(state.error, "We couldn't find that.");
      expect(state.ride, isNull);
    });

    test("merges status transitions from matching socket events", () async {
      repo.getByIdResult = _ok(_rideWith("accepted"));
      final c = container();
      addTearDown(c.dispose);

      c.read(trackingProvider(100).notifier);
      await c.pump();

      socket.receive("ride:updated", {"rideId": 100, "status": "en_route"});
      await c.pump();

      expect(c.read(trackingProvider(100)).ride?.status, "en_route");
    });

    test("ignores socket events for other rides", () async {
      final c = container();
      addTearDown(c.dispose);

      c.read(trackingProvider(100).notifier);
      await c.pump();

      socket.receive("ride:updated", {"rideId": 999, "status": "en_route"});
      await c.pump();

      expect(c.read(trackingProvider(100)).ride?.status, "requested");
    });

    test("joins the driver location room once the ride is accepted",
        () async {
      repo.getByIdResult = _ok(_rideWith("accepted"));
      final c = container();
      addTearDown(c.dispose);

      c.read(trackingProvider(100).notifier);
      await c.pump();
      await c.pump(); // allow the post-load join pass

      expect(socket.locationJoins, [40]);
    });

    test("does not stream-hold locations before any heartbeat", () async {
      final c = container();
      addTearDown(c.dispose);

      c.read(trackingProvider(100).notifier);
      await c.pump();

      expect(c.read(trackingProvider(100)).driverPosition, isNull);
    });

    test("live heartbeats update the last-known driver position", () async {
      final c = container();
      addTearDown(c.dispose);

      c.read(trackingProvider(100).notifier);
      await c.pump();

      socket.receive("driver:location", {"lat": 11.5711, "lng": 104.9203});
      await c.pump();

      final pos = c.read(trackingProvider(100)).driverPosition!;
      expect(pos.latitude, closeTo(11.5711, 0.00001));
      expect(pos.longitude, closeTo(104.9203, 0.00001));
    });

    test("cancel dispatches the repo call while cancellable and merges "
        "the server verdict", () async {
      repo.getByIdResult = _ok(_rideWith("requested"));
      final c = container();
      addTearDown(c.dispose);

      final notifier = c.read(trackingProvider(100).notifier);
      await c.pump();

      await notifier.cancel();

      expect(repo.actCalls, [(100, RideAction.cancel)]);
      expect(c.read(trackingProvider(100)).ride?.status, "cancelled");
      expect(c.read(trackingProvider(100)).canceling, false);
    });

    test("cancel is gated off outside requested|accepted|en_route",
        () async {
      repo.getByIdResult = _ok(_rideWith("completed"));
      final c = container();
      addTearDown(c.dispose);

      final notifier = c.read(trackingProvider(100).notifier);
      await c.pump();

      await notifier.cancel();

      expect(repo.actCalls, isEmpty);
      expect(c.read(trackingProvider(100)).ride?.status, "completed");
    });

    test("a rejected cancel surfaces the mapped message and keeps the "
        "ride", () async {
      repo.getByIdResult = _ok(_rideWith("en_route"));
      repo.actResult = const ApiResult.err(
        "RIDE_INVALID_TRANSITION",
        "That ride can't be updated from its current state.",
      );
      final c = container();
      addTearDown(c.dispose);

      final notifier = c.read(trackingProvider(100).notifier);
      await c.pump();

      await notifier.cancel();

      expect(repo.actCalls, [(100, RideAction.cancel)]);
      final state = c.read(trackingProvider(100));
      // Server said no → error shown, verdict NOT merged optimistically.
      expect(state.error, "That ride can't be updated from its current state.");
      expect(state.canceling, false);
      expect(state.ride?.status, "en_route");
    });
  });

  group("TrackingScreen", () {
    late _StubRideRepo repo;
    late _FakeSocket socket;

    setUp(() {
      repo = _StubRideRepo();
      socket = _FakeSocket();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: "/tracking/100",
        routes: [
          GoRoute(
            path: "/tracking/:rideId",
            builder: (_, state) => TrackingScreen(
              rideId: int.parse(state.pathParameters["rideId"]!),
              tileLayer: _tileLayer,
            ),
          ),
          GoRoute(
            path: "/rating/:rideId",
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text("rating-stub"))),
          ),
          GoRoute(
            path: "/customer",
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text("deck"))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRepoProvider.overrideWithValue(repo),
            socketClientProvider.overrideWithValue(socket),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    testWidgets("renders map pins, dashed route and the requested step",
        (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const Key("pickup-pin")), findsOneWidget);
      expect(find.byKey(const Key("dropoff-pin")), findsOneWidget);
      // No heartbeat yet → the live marker stays hidden.
      expect(find.byKey(const Key("driver-pin")), findsNothing);

      expect(find.text("Requested"), findsOneWidget);
      expect(find.text("Central Market"), findsOneWidget);
      expect(find.text("Airport"), findsOneWidget);

      // Customer may cancel a merely-requested ride (§2).
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, "Cancel ride"),
      );
      expect(button.onPressed, isNotNull);

      // Still waiting → no driver card yet.
      expect(find.text("Dara"), findsNothing);
    });

    testWidgets("shows the driver info card once accepted", (tester) async {
      repo.getByIdResult = _ok(_rideWith("accepted"));
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text("Dara"), findsOneWidget);
      expect(find.text("+855 333 333"), findsOneWidget);
      expect(find.text("Toyota Highlander SUV · PP-1A-2345"),
          findsOneWidget);
      expect(find.text("Accepted"), findsOneWidget);

      // Real distance + ETA row, computed from the ride's coords.
      expect(find.textContaining("min ETA"), findsOneWidget);
      expect(find.textContaining("km ·"), findsOneWidget);
    });

    testWidgets("driver card shows the vehicle photo when the snapshot "
        "carries one", (tester) async {
      repo.getByIdResult = _ok(_rideWithPhotos("accepted"));
      await pumpScreen(tester);

      // One frame: enough for the tree, not long enough for the (blocked)
      // image fetch to fail into its fallback.
      await tester.pump();

      final urls = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .whereType<NetworkImage>()
          .map((n) => n.url)
          .where((url) => url.contains("/uploads/"))
          .toList();
      expect(urls, ["http://10.0.2.2:3000/uploads/bike.webp"]);
    });

    testWidgets("distance and ETA helpers mirror the server's rule",
        (tester) async {
      // Server twin: etaMinutes(km) = ceil(km / 25).
      expect(etaMinutesForKm(0), 0);
      expect(etaMinutesForKm(25), 1);
      expect(etaMinutesForKm(25.1), 2);
      expect(etaMinutesForKm(50), 2);

      // Central Market → Airport: a sane Phnom-Penh trip (~4 km).
      final km = haversineKm(11.5564, 104.9282, 11.5449, 104.8922);
      expect(km, greaterThan(3.0));
      expect(km, lessThan(5.0));
    });

    testWidgets("live heartbeats move the driver pin onto the map",
        (tester) async {
      repo.getByIdResult = _ok(_rideWith("accepted"));
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("driver-pin")), findsNothing);

      socket.receive("driver:location", {"lat": 11.5711, "lng": 104.9203});
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("driver-pin")), findsOneWidget);
    });

    testWidgets("Cancel ride dispatches cancel and lands on the "
        "terminal note", (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Cancel ride"));
      await tester.pumpAndSettle();

      expect(repo.actCalls, [(100, RideAction.cancel)]);
      expect(find.text("Your ride was cancelled"), findsOneWidget);
    });

    testWidgets("a completed ride hands over to the rating stub",
        (tester) async {
      repo.getByIdResult = _ok(_rideWith("completed"));
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text("rating-stub"), findsOneWidget);
    });
  });
}
