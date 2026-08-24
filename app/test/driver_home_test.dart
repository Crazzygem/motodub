import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/driver_repo.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/api/socket_client.dart";
import "package:motodub/core/auth/auth_state.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/core/router/app_router.dart";
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

const _onlineVehicle = Driver(
  id: 4,
  userId: 40,
  carModel: "Honda Dream",
  plate: "PP-1A-2345",
  licenseNo: "KH-DL-1111",
  verified: true,
  online: true,
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

/// Ride with a created_at and an optional received rating — feeds the
/// earnings/activity rollup (rides/mine).
Ride _statusRide(
  int id,
  String status, {
  int? rating,
  required DateTime at,
}) =>
    Ride(
      id: id,
      customerId: 9,
      driverId: 40,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
      customerRating: rating,
      createdAt: at,
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

  /// When set, setOnline parks until released — lets tests observe the
  /// in-flight window (optimistic UI, double-tap guard).
  Completer<void>? setOnlineGate;

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
    if (setOnlineGate != null) await setOnlineGate!.future;
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
  void connect() {
    connectCalls++;
    // Pretend the handshake completed so isConnected-driven behavior
    // (heartbeat liveness checks) runs for real in tests.
    handleEvent("__connect", null);
  }

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

/// Records logout dispatches instead of touching storage; flipping to an
/// empty session drives the real router redirect.
class _SpyAuth extends AuthNotifier {
  _SpyAuth(this.session);

  final AuthState session;
  int logoutCalls = 0;

  @override
  Future<AuthState> build() async => session;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncData(AuthState());
  }
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
    // The server-confirmed response is adopted as the UI truth.
    expect(find.text("You're online"), findsOneWidget);
    expect(find.text("Receiving ride requests"), findsOneWidget);

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

  testWidgets("toggle shows the requested presence immediately while the "
      "PATCH is still in flight (optimistic)", (tester) async {
    final socket = _FakeSocket();
    final driverRepo = _StubDriverRepo(meResult: const ApiResult.ok(_vehicle))
      ..setOnlineGate = Completer<void>();
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump(); // optimistic state lands; PATCH still parked

    expect(driverRepo.onlineCalls, [true]);
    expect(find.text("You're online"), findsOneWidget);

    driverRepo.setOnlineGate!.complete();
    await tester.pumpAndSettle();

    // Server confirmed — the optimistic flip sticks and heartbeats run.
    expect(find.text("You're online"), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(socket.locationUpdates, isNotEmpty);
  });

  testWidgets("taps during an in-flight toggle are ignored — one dispatch, "
      "no polarity race", (tester) async {
    final socket = _FakeSocket();
    final driverRepo = _StubDriverRepo(meResult: const ApiResult.ok(_vehicle))
      ..setOnlineGate = Completer<void>();
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump(); // switch now displays ON
    await tester.tap(find.byType(Switch)); // rapid second tap → would be OFF
    driverRepo.setOnlineGate!.complete();
    await tester.pumpAndSettle();

    expect(driverRepo.onlineCalls, [true]); // exactly one PATCH, polarity kept
    expect(find.text("You're online"), findsOneWidget);
  });

  testWidgets("toggle PATCH failure reverts offline, surfaces the reason, "
      "and never starts heartbeats", (tester) async {
    final socket = _FakeSocket();
    final driverRepo = _StubDriverRepo(meResult: const ApiResult.ok(_vehicle))
      ..setOnlineResult = const ApiResult.err("NETWORK", "network gone");
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(driverRepo.onlineCalls, [true]);
    expect(find.text("network gone"), findsOneWidget); // mapped error surfaced
    expect(find.text("You're online"), findsNothing); // reverted

    await tester.pump(const Duration(seconds: 11));
    expect(socket.locationUpdates, isEmpty); // fail-safe: no heartbeats
  });

  testWidgets("fresh boot mirrors the SERVER profile: offline profile means "
      "an OFF switch and a quiet heartbeat timer", (tester) async {
    final socket = _FakeSocket();
    final driverRepo =
        _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)); // online:false
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    expect(driverRepo.onlineCalls, isEmpty);
    expect(find.text("You're offline"), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(socket.locationUpdates, isEmpty); // nothing restored from cache
  });

  testWidgets("fresh boot mirrors the SERVER profile: online profile means "
      "ON and heartbeats stream right away", (tester) async {
    final socket = _FakeSocket();
    final driverRepo =
        _StubDriverRepo(meResult: const ApiResult.ok(_onlineVehicle));
    await _pumpHarness(
      tester,
      driverRepo: driverRepo,
      rideRepo: _StubRideRepo(),
      socket: socket,
    );
    await tester.pumpAndSettle();

    expect(find.text("You're online"), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(socket.locationUpdates, isNotEmpty);
    expect(socket.locationUpdates.first.lat, closeTo(11.5564, 0.0001));
    expect(socket.locationUpdates.first.lng, closeTo(104.9282, 0.0001));
  });

  testWidgets("a heartbeat tick with the socket down fails safe: UI flips "
      "offline and heartbeats freeze", (tester) async {
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
    expect(find.text("You're online"), findsOneWidget);

    socket.handleEvent("__disconnect", null); // connection dies mid-session
    await tester.pump(const Duration(seconds: 5)); // next tick notices

    expect(find.text("You're offline"), findsOneWidget);

    final frozenAt = socket.locationUpdates.length;
    await tester.pump(const Duration(seconds: 11));
    expect(socket.locationUpdates.length, frozenAt); // timer stopped
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

  testWidgets("earnings summary shows today's completed count and average "
      "rating from rides/mine", (tester) async {
    final now = DateTime.now();
    final rideRepo = _StubRideRepo()
      ..mineResult = ApiResult.ok([
        _statusRide(1, "completed", rating: 5, at: now),
        _statusRide(2, "completed", rating: 4, at: now),
        // Yesterday's completion — not part of "today", but its rating is.
        _statusRide(3, "completed",
            rating: 3, at: now.subtract(const Duration(days: 1))),
        _statusRide(4, "cancelled", at: now),
      ]);
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: rideRepo,
    );
    await tester.pumpAndSettle();

    expect(find.text("Today"), findsOneWidget);
    expect(find.text("2"), findsOneWidget); // completed today, not yesterday
    expect(find.text("4.0"), findsOneWidget); // avg over all 3 ratings
  });

  testWidgets("activity lists the last five rides with status chips and "
      "relative time", (tester) async {
    final now = DateTime.now();
    final rideRepo = _StubRideRepo()
      ..mineResult = ApiResult.ok([
        for (var i = 6; i >= 1; i--)
          _statusRide(i, "completed",
              at: now.subtract(Duration(minutes: i * 5))),
      ]);
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: rideRepo,
    );
    await tester.pumpAndSettle();

    expect(find.text("Recent activity"), findsOneWidget);
    // Newest five of six — the oldest (30m ago) is cut.
    expect(find.text("Completed"), findsNWidgets(5));
    expect(find.text("5m ago"), findsOneWidget);
    expect(find.text("30m ago"), findsNothing);
    expect(find.textContaining("Central Market"), findsWidgets);
  });

  testWidgets("shows the empty activity state when there are no rides", (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: _StubRideRepo(),
    );
    await tester.pumpAndSettle();

    expect(find.text("Today"), findsOneWidget);
    expect(find.text("No rides yet"), findsOneWidget);
  });

  testWidgets("summary surfaces a mapped error with retry", (tester) async {
    final rideRepo = _StubRideRepo()
      ..mineResult = const ApiResult.err("NETWORK", "network gone");
    await _pumpHarness(
      tester,
      driverRepo: _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      rideRepo: rideRepo,
    );
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
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

  testWidgets("logout dispatches the auth logout and lands on the login "
      "screen through the router redirect", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final auth = _SpyAuth(const AuthState(token: "jwt", role: "driver"));
    final container = ProviderContainer(overrides: [
      driverRepoProvider.overrideWithValue(
        _StubDriverRepo(meResult: const ApiResult.ok(_vehicle)),
      ),
      rideRepoProvider.overrideWithValue(_StubRideRepo()),
      socketClientProvider.overrideWithValue(_FakeSocket()),
      authProvider.overrideWith(() => auth),
    ]);
    addTearDown(container.dispose);

    // Same wiring as app.dart: the router reacts to auth-state changes.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(appRouterProvider),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsOneWidget); // session → /driver

    await tester.tap(find.text("Log out"));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(Switch), findsNothing);
    expect(find.widgetWithText(FilledButton, "Log in"), findsOneWidget);
  });
}
