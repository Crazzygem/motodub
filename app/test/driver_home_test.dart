import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/driver_repo.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/api/socket_client.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/features/booking/booking_provider.dart" show rideRepoProvider;
import "package:motodub/features/deck/deck_provider.dart" show driverRepoProvider;
import "package:motodub/features/driver/driver_home_screen.dart";
import "package:motodub/features/driver/driver_provider.dart";

const _vehicle = Driver(
  id: 4,
  userId: 40,
  carModel: "Honda Dream",
  plate: "PP-1A-2345",
  licenseNo: "KH-DL-1111",
  verified: true,
  online: false,
  pricePerKm: 1.20,
);

const _requestedRide = Ride(
  id: 100,
  customerId: 9,
  driverId: 40,
  status: "requested",
  pickupLat: 11.5564,
  pickupLng: 104.9282,
  pickupAddress: "Central Market",
  dropoffLat: 11.5449,
  dropoffLng: 104.8922,
  dropoffAddress: "Airport",
  customerName: "Srey",
  customerAvgRating: 4.5,
);

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

ApiClient _deadClient() => ApiClient(dio: Dio());

/// Records every toggle/create call instead of doing HTTP.
class _StubDriverRepo extends DriverRepo {
  _StubDriverRepo({
    this.meResult = const ApiResult.err("NOT_FOUND", "nope"),
  }) : super(_deadClient());

  ApiResult<Driver> meResult;
  ApiResult<Driver>? setOnlineResult;
  ApiResult<Driver>? createResult;

  final List<bool> onlineCalls = <bool>[];
  Map<String, dynamic>? createdPayload;

  @override
  Future<ApiResult<Driver>> me() async => meResult;

  @override
  Future<ApiResult<Driver>> setOnline(
    bool online, {
    double? lat,
    double? lng,
  }) async {
    onlineCalls.add(online);
    return setOnlineResult ??
        ApiResult.ok(Driver(
          id: _vehicle.id,
          userId: _vehicle.userId,
          carModel: _vehicle.carModel,
          plate: _vehicle.plate,
          licenseNo: _vehicle.licenseNo,
          verified: _vehicle.verified,
          online: online,
          pricePerKm: _vehicle.pricePerKm,
        ));
  }

  @override
  Future<ApiResult<Driver>> createVehicle({
    required String carModel,
    required String plate,
    required String licenseNo,
    required double pricePerKm,
  }) async {
    createdPayload = {
      "car_model": carModel,
      "plate": plate,
      "license_no": licenseNo,
      "price_per_km": pricePerKm,
    };
    return createResult ?? const ApiResult.ok(_vehicle);
  }
}

/// Records ride actions; getById/mine serve canned results.
class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(_deadClient());

  ApiResult<Ride>? getByIdResult;
  ApiResult<List<Ride>>? mineResult;
  ApiResult<Ride>? actResult;

  final List<(int, RideAction)> actCalls = <(int, RideAction)>[];

  @override
  Future<ApiResult<Ride>> getById(int id) async =>
      getByIdResult ?? ApiResult.ok(_ride("requested"));

  @override
  Future<ApiResult<List<Ride>>> mine() async =>
      mineResult ?? const ApiResult.ok([]);

  @override
  Future<ApiResult<Ride>> act(int id, RideAction action) async {
    actCalls.add((id, action));
    return actResult ?? ApiResult.ok(_ride(switch (action) {
      RideAction.accept => "accepted",
      RideAction.start => "en_route",
      RideAction.startRide => "in_progress",
      _ => "completed",
    }));
  }
}

/// No-network socket double: records writes, never opens anything.
class _FakeSocket extends SocketClient {
  _FakeSocket() : super(baseUrl: "http://127.0.0.1:1", token: "jwt");

  final List<({double lat, double lng})> locationUpdates =
      <({double lat, double lng})>[];
  int connectCalls = 0;

  @override
  void connect() => connectCalls++;

  @override
  void sendLocationUpdate(double lat, double lng) {
    locationUpdates.add((lat: lat, lng: lng));
  }
}

/// Seeds the provider without any REST/socket bootstrap.
class _SeededHome extends DriverNotifier {
  _SeededHome(this.seed);

  final DriverHomeState seed;

  @override
  Future<DriverHomeState> build() async => seed;
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required _StubDriverRepo driverRepo,
  required _StubRideRepo rideRepo,
  _FakeSocket? socket,
  DriverNotifier Function()? homeOverride,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverRepoProvider.overrideWithValue(driverRepo),
        rideRepoProvider.overrideWithValue(rideRepo),
        socketClientProvider.overrideWithValue(socket ?? _FakeSocket()),
        if (homeOverride != null)
          driverProvider.overrideWith(homeOverride),
      ],
      child: const MaterialApp(home: DriverHomeScreen()),
    ),
  );
}

void main() {
  testWidgets("online switch dispatches PATCH /drivers/online and starts "
      "5s heartbeats at the fallback position", (tester) async {
    final socket = _FakeSocket();
    final driverRepo = _StubDriverRepo(
      // Profile exists but offline — the boot state under test.
      meResult: const ApiResult.ok(_vehicle),
    );
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsOneWidget);
    expect(driverRepo.onlineCalls, isEmpty);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(driverRepo.onlineCalls, [true]);

    // One heartbeat period later the fix went out over the socket seam —
    // no geolocator plugin exists yet, so the PP-center fallback applies.
    await tester.pump(const Duration(seconds: 5));

    expect(socket.locationUpdates, isNotEmpty);
    expect(socket.locationUpdates.first.lat, closeTo(11.5564, 0.0001));
    expect(socket.locationUpdates.first.lng, closeTo(104.9282, 0.0001));
  });

  testWidgets("going offline stops the heartbeat stream", (tester) async {
    final socket = _FakeSocket();
    final driverRepo = _StubDriverRepo(meResult: const ApiResult.ok(_vehicle));
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch)); // online
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 11));
    final whileOnline = socket.locationUpdates.length;
    expect(whileOnline, greaterThanOrEqualTo(2));

    await tester.tap(find.byType(Switch)); // offline again
    await tester.pumpAndSettle();

    expect(driverRepo.onlineCalls, [true, false]);

    await tester.pump(const Duration(seconds: 12));
    expect(socket.locationUpdates.length, whileOnline); // frozen
  });

  testWidgets("first-time setup form submits the vehicle-create payload", (
    tester,
  ) async {
    final driverRepo = _StubDriverRepo(); // me → NOT_FOUND: setup needed
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
    );
    await tester.pumpAndSettle();

    expect(find.text("Car model"), findsOneWidget);
    expect(find.byType(Switch), findsNothing); // no profile → can't go online

    await tester.enterText(
      find.widgetWithText(TextFormField, "Car model"),
      "Honda Dream",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Plate"),
      "PP-1A-2345",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "License no"),
      "KH-DL-1111",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Price per km"),
      "1.20",
    );
    await tester.tap(find.text("Save vehicle"));
    await tester.pumpAndSettle();

    expect(driverRepo.createdPayload, {
      "car_model": "Honda Dream",
      "plate": "PP-1A-2345",
      "license_no": "KH-DL-1111",
      "price_per_km": 1.20,
    });
    // The saved profile replaces the form.
    expect(find.text("Honda Dream · PP-1A-2345"), findsOneWidget);
  });

  testWidgets("renders the vehicle info card from the own profile", (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: _StubRideRepo(),
    );
    await tester.pumpAndSettle();

    expect(find.text("Honda Dream · PP-1A-2345"), findsOneWidget);
    expect(find.text("1.20 /km"), findsOneWidget);
    expect(find.text("Car model"), findsNothing); // not the setup form
  });

  testWidgets("incoming request renders and Decline dispatches the decline "
      "action", (tester) async {
    final rideRepo = _StubRideRepo();
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: rideRepo,
      homeOverride: () => _SeededHome(const DriverHomeState(
        online: true,
        vehicle: _vehicle,
        incoming: _requestedRide,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text("Srey"), findsOneWidget);

    await tester.tap(find.text("Decline"));
    await tester.pumpAndSettle();

    expect(rideRepo.actCalls, [(100, RideAction.decline)]);
  });

  testWidgets("Accept dispatches the accept action", (tester) async {
    final rideRepo = _StubRideRepo();
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: rideRepo,
      homeOverride: () => _SeededHome(const DriverHomeState(
        online: true,
        vehicle: _vehicle,
        incoming: _requestedRide,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Accept"));
    await tester.pumpAndSettle();

    expect(rideRepo.actCalls, [(100, RideAction.accept)]);
    // The request card gives way to the active-ride controls.
    expect(find.text("Decline"), findsNothing);
    expect(find.text("On my way"), findsOneWidget);
  });

  testWidgets("active accepted ride advances via 'On my way'", (tester) async {
    final rideRepo = _StubRideRepo();
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: rideRepo,
      homeOverride: () => _SeededHome(DriverHomeState(
        online: true,
        vehicle: _vehicle,
        active: _ride("accepted"),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text("On my way"), findsOneWidget);
    await tester.tap(find.text("On my way"));
    await tester.pumpAndSettle();

    expect(rideRepo.actCalls, [(100, RideAction.start)]);
    expect(find.text("Start ride"), findsOneWidget);
  });
}
