import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:duboun/core/api/api_client.dart";
import "package:duboun/core/api/ride_repo.dart";
import "package:duboun/core/models/driver.dart";
import "package:duboun/core/models/ride.dart";
import "package:duboun/features/booking/booking_provider.dart";
import "package:duboun/features/booking/booking_sheet.dart";

const _driver = Driver(
  id: 7,
  userId: 4,
  carModel: "Honda Dream",
  plate: "PP-1A-2345",
  licenseNo: "L-99887",
  verified: true,
  online: true,
  pricePerKm: 1.20,
  name: "Dara Sok",
  rating: 4.8,
  etaMinutes: 4,
);

const _requestedRide = Ride(
  id: 100,
  customerId: 1,
  driverId: 4,
  status: "requested",
  pickupLat: 11.5564,
  pickupLng: 104.9282,
  pickupAddress: "Central Market",
  dropoffLat: 11.5449,
  dropoffLng: 104.8922,
  dropoffAddress: "Airport",
);

class _StubRepo extends RideRepo {
  _StubRepo(this.result) : super(_deadClient());

  final ApiResult<Ride> result;

  static ApiClient _deadClient() => ApiClient(dio: Dio());

  @override
  Future<ApiResult<Ride>> create({
    required int driverId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
  }) async =>
      result;
}

Widget _harness({
  required RideRepo repo,
  bool routed = false,
  Driver driver = _driver,
}) {
  final sheet = BookingSheet(driver: driver, tileLayer: const SizedBox.shrink());

  if (!routed) {
    return ProviderScope(
      overrides: [rideRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(home: Scaffold(body: sheet)),
    );
  }

  // Success path opens the REAL sheet over a page, then must pop it and land
  // on /tracking/{id}.
  final router = GoRouter(
    initialLocation: "/booking-test",
    routes: [
      GoRoute(
        path: "/booking-test",
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showBookingSheet(
                context,
                _driver,
                tileLayer: const SizedBox.shrink(),
              ),
              child: const Text("Open booking sheet"),
            ),
          ),
        ),
      ),
      GoRoute(
        path: "/tracking/:id",
        builder: (_, state) => Text("Tracking ride ${state.pathParameters["id"]}"),
      ),
    ],
  );
  return ProviderScope(
    overrides: [rideRepoProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _pumpSheet(
  WidgetTester tester,
  RideRepo repo, {
  bool routed = false,
  Driver driver = _driver,
}) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  return _harness(repo: repo, routed: routed, driver: driver);
}

Future<void> _fillAddresses(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, "Pickup address"),
    "Central Market",
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, "Dropoff address"),
    "Airport",
  );
  await tester.pump();
}

void main() {
  testWidgets("sheet renders the driver mini-header", (tester) async {
    await tester.pumpWidget(_pumpSheet(
      tester,
      _StubRepo(const ApiResult.ok(null)),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Dara Sok"), findsOneWidget);
    expect(find.text("Honda Dream · PP-1A-2345"), findsOneWidget);
    expect(find.text("4.8"), findsOneWidget);
    expect(find.text("1.20 /km"), findsOneWidget);
  });

  testWidgets("mini-header prefers vehicle_photo over the avatar photo",
      (tester) async {
    await tester.pumpWidget(_pumpSheet(
      tester,
      _StubRepo(const ApiResult.ok(null)),
      driver: const Driver(
        id: 7,
        userId: 4,
        carModel: "Honda Dream",
        plate: "PP-1A-2345",
        licenseNo: "L-99887",
        verified: true,
        online: true,
        pricePerKm: 1.20,
        name: "Dara Sok",
        photo: "/uploads/face.png",
        rating: 4.8,
        etaMinutes: 4,
        vehiclePhoto: "/uploads/bike.webp",
      ),
    ));
    // One frame: enough for the tree, not long enough for the (unreachable
    // in tests) photo fetch to fall into its errorBuilder.
    await tester.pump();

    // The shared DriverPhotoAvatar renders the photo as an Image.network —
    // exactly one /uploads image, and it's the VEHICLE photo.
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<NetworkImage>()
        .map((n) => n.url)
        .where((url) => url.contains("/uploads/"))
        .toList();
    expect(urls, ["http://10.0.2.2:3000/uploads/bike.webp"]);
  });

  testWidgets("sheet renders map with both pins and address fields",
      (tester) async {
    await tester.pumpWidget(_pumpSheet(
      tester,
      _StubRepo(const ApiResult.ok(null)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    // flutter_map Markers/polylines are data objects, not widgets — the pins'
    // glyphs are what actually renders.
    expect(find.byIcon(Icons.trip_origin_rounded), findsWidgets); // pickup pin
    expect(find.byIcon(Icons.location_on_rounded), findsWidgets); // dropoff pin

    expect(find.text("Pickup address"), findsOneWidget);
    expect(find.text("Dropoff address"), findsOneWidget);
    expect(find.text("Confirm booking"), findsOneWidget);
  });

  testWidgets("tapping a pin chip switches which pin map taps move",
      (tester) async {
    await tester.pumpWidget(_pumpSheet(
      tester,
      _StubRepo(const ApiResult.ok(null)),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Pickup"), findsOneWidget);
    expect(find.text("Dropoff"), findsOneWidget);

    await tester.tap(find.text("Dropoff"));
    await tester.pumpAndSettle();

    // No crash, chips still present — active-pin state is internal.
    expect(find.text("Pickup"), findsOneWidget);
    expect(find.text("Dropoff"), findsOneWidget);
  });

  testWidgets("failed confirm shows the mapped error banner in the sheet",
      (tester) async {
    await tester.pumpWidget(_pumpSheet(
      tester,
      _StubRepo(const ApiResult.err(
        "RIDE_BUSY_DRIVER",
        "This driver is busy right now. Try another one.",
      )),
    ));
    await tester.pumpAndSettle();
    await _fillAddresses(tester);

    await tester.tap(find.text("Confirm booking"));
    await tester.pumpAndSettle();

    expect(
      find.text("This driver is busy right now. Try another one."),
      findsOneWidget,
    );
    // The sheet stays open so the customer can pick another driver.
    expect(find.text("Confirm booking"), findsOneWidget);
  });

  testWidgets("successful confirm pops the sheet and pushes /tracking/{id}",
      (tester) async {
    await tester.pumpWidget(_pumpSheet(
      tester,
      _StubRepo(const ApiResult.ok(_requestedRide)),
      routed: true,
    ));
    await tester.pumpAndSettle();

    // Real entry point: open the sheet over the page first.
    await tester.tap(find.text("Open booking sheet"));
    await tester.pumpAndSettle();
    await _fillAddresses(tester);

    await tester.tap(find.text("Confirm booking"));
    await tester.pumpAndSettle();

    expect(find.text("Tracking ride 100"), findsOneWidget);
    expect(find.text("Confirm booking"), findsNothing); // sheet is gone
  });
}
