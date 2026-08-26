import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/admin_repo.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/error_messages.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/api/socket_client.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/features/admin/admin_screen.dart";
import "package:motodub/features/admin/dashboard_tab.dart";
import "package:motodub/features/admin/drivers_tab.dart";
import "package:motodub/features/admin/rides_tab.dart";
import "package:motodub/features/booking/booking_provider.dart"
    show rideRepoProvider;
import "package:motodub/features/driver/driver_provider.dart"
    show socketClientProvider;

// Task 6.2 — admin dashboard: KPI cards off GET /api/admin/stats, the
// verification table with modal-gated approve/suspend (PROJECT.md §6), and
// the status-filterable ride feed that reconciles on `ride:updated`.
//
// Isolation: repos subclass the real ones over a dead Dio client; the socket
// is a no-network double fed through handleEvent — same convention as
// history_test / tracking_test.
AdminStats _stats() => const AdminStats(
      requestedNow: 2,
      onlineDrivers: 1,
      completedToday: 3,
      avgRating: 4.75,
    );

AdminDriver _driver({
  required int driverId,
  required int userId,
  required String name,
  required String email,
  double rating = 4.8,
  bool active = true,
  double pricePerKm = 1.2,
  bool verified = true,
  bool online = true,
  String? phone,
  String? carModel,
  String? plate,
  String? licenseNo,
}) =>
    AdminDriver(
      driverId: driverId,
      userId: userId,
      name: name,
      email: email,
      rating: rating,
      active: active,
      pricePerKm: pricePerKm,
      verified: verified,
      online: online,
      phone: phone,
      carModel: carModel,
      plate: plate,
      licenseNo: licenseNo,
    );

Ride _ride({
  required int id,
  required String status,
  String customerName = "Srey",
  String? driverName,
}) =>
    Ride(
      id: id,
      customerId: 9,
      driverId: driverName == null ? 0 : 40,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
      createdAt: DateTime(2026, 8, 22, 9, 15),
      updatedAt: DateTime(2026, 8, 22, 9, 40),
      customerName: customerName,
      driverName: driverName,
    );

ApiClient _deadClient() => ApiClient(dio: Dio());

/// Serves canned results and records every call the tabs make.
class _StubAdminRepo extends AdminRepo {
  _StubAdminRepo() : super(_deadClient());

  ApiResult<AdminStats> statsResult = ApiResult.ok(_stats());
  List<AdminDriver> driverRows = [
    _driver(driverId: 11, userId: 41, name: "Dara", email: "dara@taxi.demo"),
    _driver(
      driverId: 33,
      userId: 43,
      name: "Vuthy",
      email: "vuthy@taxi.demo",
      rating: 5.0,
      pricePerKm: 0.9,
      verified: false,
      online: false,
    ),
    _driver(
      driverId: 52,
      userId: 44,
      name: "Sophea",
      email: "sophea@taxi.demo",
      rating: 4.1,
      active: false,
      online: false,
      pricePerKm: 1.1,
    ),
  ];

  List<Ride> rideRows = const <Ride>[];
  ApiResult<Ride> fetchResult =
      ApiResult.ok(_ride(id: 300, status: "completed", driverName: "Dara"));

  int statsCalls = 0;
  int driversCalls = 0;
  final List<String?> statusQueries = <String?>[];
  final List<int> verifyCalls = <int>[];
  final List<int> suspendCalls = <int>[];

  // Bots card + driver edit (Seth directive).
  ApiResult<BotsStatus> botsStatusResult =
      ApiResult.ok(const BotsStatus(running: false));
  ApiResult<BotsStatus> startResult = ApiResult.ok(
    const BotsStatus(
      running: true,
      ridesSpawned: 4,
      uptimeSec: 5,
      lastRideAt: "2026-08-26T09:30:00",
    ),
  );

  /// When set, startBots hangs until completed — lets tests observe the
  /// busy surface mid-flight.
  Completer<ApiResult<BotsStatus>>? startGate;

  final List<int> startCalls = <int>[];
  int stopCalls = 0;
  bool stoppedSinceStart = false; // stop() flips the reconcile snapshot
  final List<(int, Map<String, dynamic>)> patchCalls =
      <(int, Map<String, dynamic>)>[];
  ApiResult<AdminDriver>? patchResult; // error injection

  @override
  Future<ApiResult<AdminStats>> stats() async {
    statsCalls++;
    return statsResult;
  }

  @override
  Future<ApiResult<List<AdminDriver>>> drivers() async {
    driversCalls++;
    return ApiResult.ok(List.of(driverRows));
  }

  @override
  Future<ApiResult<List<Ride>>> rides({String? status}) async {
    statusQueries.add(status);
    final rows = (status == null)
        ? rideRows
        : rideRows.where((r) => r.status == status).toList();
    return ApiResult.ok(rows);
  }

  @override
  Future<ApiResult<AdminDriver>> verifyDriver(int driverRowId) async {
    verifyCalls.add(driverRowId);
    return ApiResult.ok(_flipped(driverRowId, verified: true));
  }

  @override
  Future<ApiResult<AdminDriver>> suspendDriver(int driverRowId) async {
    suspendCalls.add(driverRowId);
    return ApiResult.ok(_flipped(driverRowId, active: false));
  }

  AdminDriver _flipped(int driverRowId, {bool? verified, bool? active}) {
    final row = driverRows.firstWhere((d) => d.driverId == driverRowId);
    return AdminDriver(
      driverId: row.driverId,
      userId: row.userId,
      name: row.name,
      email: row.email,
      rating: row.rating,
      active: active ?? row.active,
      pricePerKm: row.pricePerKm,
      verified: verified ?? row.verified,
      online: row.online,
    );
  }

  @override
  Future<ApiResult<BotsStatus>> botsStatus() async {
    if (stoppedSinceStart) {
      // The bare stop answer — reconcile sees the zeroed snapshot.
      return ApiResult.ok(const BotsStatus(running: false));
    }
    return botsStatusResult;
  }

  @override
  Future<ApiResult<BotsStatus>> startBots(int count) async {
    startCalls.add(count);
    final gate = startGate;
    if (gate != null) return gate.future;
    return startResult;
  }

  @override
  Future<ApiResult<BotsStatus>> stopBots() async {
    stopCalls++;
    stoppedSinceStart = true;
    return ApiResult.ok(const BotsStatus(running: false));
  }

  @override
  Future<ApiResult<AdminDriver>> patchDriver(
    int driverRowId,
    Map<String, dynamic> fields,
  ) async {
    patchCalls.add((driverRowId, Map.of(fields)));
    final injected = patchResult;
    if (injected != null) return injected;

    final row = driverRows.firstWhere((d) => d.driverId == driverRowId);
    final updated = AdminDriver(
      driverId: row.driverId,
      userId: row.userId,
      name: (fields["name"] as String?) ?? row.name,
      email: row.email,
      phone: (fields["phone"] as String?) ?? row.phone,
      rating: row.rating,
      active: row.active,
      pricePerKm: (fields["price_per_km"] as double?) ?? row.pricePerKm,
      verified: row.verified,
      online: row.online,
      carModel: (fields["car_model"] as String?) ?? row.carModel,
      plate: (fields["plate"] as String?) ?? row.plate,
      licenseNo: (fields["license_no"] as String?) ?? row.licenseNo,
    );
    driverRows[driverRows.indexWhere((d) => d.driverId == driverRowId)] =
        updated; // reconcile reload sees server truth
    return ApiResult.ok(updated);
  }
}

/// Minimal ride-repo double for the feed's append-on-socket path.
class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(_deadClient());

  ApiResult<Ride> getByIdResult =
      ApiResult.err("NOT_FOUND", errorMessageFor("NOT_FOUND"));

  @override
  Future<ApiResult<Ride>> getById(int id) async => getByIdResult;
}

/// No-network socket double: events enter through the real parsing seam.
class _FakeSocket extends SocketClient {
  _FakeSocket() : super(baseUrl: "http://127.0.0.1:1", token: "jwt");

  int connectCalls = 0;

  @override
  void connect() => connectCalls++;

  void receive(String event, Map<String, dynamic> payload) =>
      handleEvent(event, payload);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  _StubAdminRepo? repo,
  _StubRideRepo? rides,
  _FakeSocket? socket,
}) async {
  // Tall viewport so lazy ListViews materialize every seeded row.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repo != null) adminRepoProvider.overrideWithValue(repo),
        if (rides != null) rideRepoProvider.overrideWithValue(rides),
        if (socket != null) socketClientProvider.overrideWithValue(socket),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

/// Badge label scoped to one ride row — the filter strip carries the same
/// words, so raw text finders are ambiguous on the rides tab.
String _badgeText(WidgetTester tester, int rideId) =>
    tester.widget<Text>(
      find.descendant(
        of: find.byKey(Key("admin-ride-badge-$rideId")),
        matching: find.byType(Text),
      ),
    ).data!;

void main() {
  group("DashboardTab", () {
    testWidgets("renders KPI values from the mocked repo", (tester) async {
      final repo = _StubAdminRepo();
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();

      // Digits are scoped to the KPI grid — the Bots card's 1|2|3 pair
      // selector renders the same numerals beside it.
      final kpiGrid = find.byType(GridView);
      expect(find.descendant(of: kpiGrid, matching: find.text("2")),
          findsOneWidget); // live rides
      expect(find.descendant(of: kpiGrid, matching: find.text("1")),
          findsOneWidget); // online drivers
      expect(find.descendant(of: kpiGrid, matching: find.text("3")),
          findsOneWidget); // completed today
      expect(find.descendant(of: kpiGrid, matching: find.text("4.75")),
          findsOneWidget); // avg rating
      expect(find.text("Live rides"), findsOneWidget);
      expect(find.text("Online drivers"), findsOneWidget);
      expect(find.text("Completed today"), findsOneWidget);
      expect(find.text("Avg rating"), findsOneWidget);

      // Per-KPI icon + tint (direction_car / wifi / check_circle / star).
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets("surfaces a mapped error with working retry", (tester) async {
      final repo = _StubAdminRepo();
      repo.statsResult = const ApiResult.err(
        "NETWORK",
        networkUnreachableMessage,
      );
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text(networkUnreachableMessage), findsOneWidget);
      expect(repo.statsCalls, 1);

      repo.statsResult = ApiResult.ok(_stats());
      await tester.tap(find.text("Try again"));
      await tester.pumpAndSettle();

      expect(repo.statsCalls, 2);
      expect(find.text("4.75"), findsOneWidget);
    });
  });

  group("Bots card", () {
    testWidgets("renders the Stopped snapshot from the mocked repo",
        (tester) async {
      final repo = _StubAdminRepo()
        ..botsStatusResult = ApiResult.ok(const BotsStatus(
          running: false,
          ridesSpawned: 7,
          uptimeSec: 200,
        ));
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text("Stopped"), findsOneWidget);
      expect(find.text("Uptime 3 m 20 s"), findsOneWidget);
      expect(find.text("Rides spawned"), findsOneWidget);
      expect(find.text("7"), findsOneWidget);
      expect(find.text("Last ride"), findsOneWidget);
      expect(find.text("—"), findsOneWidget); // nothing spawned yet
      // Manual-refresh-only card: the header button is present.
      expect(find.byKey(const Key("bots-refresh")), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Start bots"), findsOneWidget);
    });

    testWidgets("start deploys the selected pair count and adopts running truth",
        (tester) async {
      final repo = _StubAdminRepo();
      repo.startGate = Completer();
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();
      expect(find.text("Stopped"), findsOneWidget);

      // Pick 3 pairs — scoped to the selector: KPI digits read the same.
      await tester.tap(find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text("3"),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("bots-toggle")));
      await tester.pump(); // mid-flight — the gate holds the future open

      expect(repo.startCalls, [3]);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key("bots-toggle"))).onPressed,
        isNull, // busy surface
      );

      repo.startGate!.complete(repo.startResult);
      await tester.pumpAndSettle();

      expect(find.text("Running"), findsOneWidget);
      expect(find.text("Uptime 5 s"), findsOneWidget);
      expect(find.text("26 Aug · 09:30"), findsOneWidget); // last ride stamp
      expect(find.widgetWithText(FilledButton, "Stop bots"), findsOneWidget);
    });

    testWidgets("stop flips to Stopped through the reconcile reload",
        (tester) async {
      final repo = _StubAdminRepo()
        ..botsStatusResult = ApiResult.ok(const BotsStatus(
          running: true,
          ridesSpawned: 9,
          uptimeSec: 3600,
        ));
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();
      expect(find.text("Running"), findsOneWidget);
      expect(find.text("Uptime 1 h 00 m"), findsOneWidget);

      await tester.tap(find.byKey(const Key("bots-toggle")));
      await tester.pumpAndSettle();

      expect(repo.stopCalls, 1);
      expect(find.text("Stopped"), findsOneWidget);
      // Reconcile adopted the bare {running:false} snapshot: counters zeroed.
      expect(find.text("Rides spawned"), findsOneWidget);
      expect(find.text("0"), findsOneWidget);
      expect(find.text("—"), findsOneWidget);
    });

    testWidgets("start failure surfaces the server message, state unchanged",
        (tester) async {
      final repo = _StubAdminRepo()
        ..startResult = const ApiResult.err(
            "BOT_ALREADY_RUNNING", "Bots manager is already running");
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("bots-toggle")));
      await tester.pumpAndSettle();

      expect(repo.startCalls, [2]); // untouched default selection
      expect(find.text("Bots manager is already running"), findsOneWidget);
      expect(find.text("Stopped"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Start bots"), findsOneWidget);
    });

    testWidgets("manual refresh recovers from a failed status read",
        (tester) async {
      final repo = _StubAdminRepo()
        ..botsStatusResult =
            const ApiResult.err("NETWORK", networkUnreachableMessage);
      await _pump(tester, const DashboardTab(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.text(networkUnreachableMessage), findsOneWidget);
      expect(find.text("Stopped"), findsNothing); // no snapshot — no claim

      repo.botsStatusResult =
          ApiResult.ok(const BotsStatus(running: false, ridesSpawned: 2));
      await tester.tap(find.byKey(const Key("bots-refresh")));
      await tester.pumpAndSettle();

      expect(find.text(networkUnreachableMessage), findsNothing);
      expect(find.text("Stopped"), findsOneWidget);
      expect(find.text("Rides spawned"), findsOneWidget);
    });
  });

  group("DriversTab", () {
    testWidgets("renders rows with status chips and gated actions",
        (tester) async {
      final repo = _StubAdminRepo();
      await _pump(tester, const DriversTab(), repo: repo);
      await tester.pumpAndSettle();

      // Chips per DESIGN.md §5: verified ok · pending warn · suspended bad.
      // Suspended is an account state — it outranks vehicle verification,
      // so sophea shows "Suspended", not "Verified".
      expect(find.text("Verified"), findsOneWidget); // dara
      expect(find.text("Pending"), findsOneWidget); // vuthy
      expect(find.text("Suspended"), findsOneWidget); // sophea
      expect(find.text("Online"), findsOneWidget); // dara only
      expect(find.text("Offline"), findsNWidgets(2));

      // Rows show identity + asking rate.
      expect(find.text("Vuthy"), findsOneWidget);
      expect(find.text("vuthy@taxi.demo"), findsOneWidget);
      expect(find.text("\$0.90/km"), findsOneWidget);
      expect(find.text("\$1.20/km"), findsOneWidget);
      expect(find.text("\$1.10/km"), findsOneWidget);

      // Approve enabled only for the unverified row; suspend enabled only
      // for accounts that are still active.
      bool enabled(Key key) =>
          tester.widget<FilledButton>(find.byKey(key)).onPressed != null;
      expect(enabled(const Key("approve-33")), isTrue); // vuthy unverified
      expect(enabled(const Key("approve-11")), isFalse); // dara verified
      expect(enabled(const Key("approve-52")), isFalse); // sophea verified
      expect(enabled(const Key("suspend-11")), isTrue); // dara active
      expect(enabled(const Key("suspend-52")), isFalse); // sophea suspended
    });

    testWidgets("Approve opens a confirm modal and verifies only on confirm",
        (tester) async {
      final repo = _StubAdminRepo();
      await _pump(tester, const DriversTab(), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("approve-33")));
      await tester.pumpAndSettle();

      // Modal first — nothing dispatched on the first tap.
      expect(find.text("Approve driver"), findsOneWidget);
      expect(repo.verifyCalls, isEmpty);

      repo.driverRows = List.of(repo.driverRows)
        ..removeWhere((d) => d.driverId == 33)
        ..add(_driver(
          driverId: 33,
          userId: 43,
          name: "Vuthy",
          email: "vuthy@taxi.demo",
          rating: 5.0,
          pricePerKm: 0.9,
        ));

      await tester.tap(find.byKey(const Key("dialog-confirm")));
      await tester.pumpAndSettle();

      expect(repo.verifyCalls, [33]); // drivers-row PK, not user_id
      expect(find.text("Pending"), findsNothing);
      expect(find.text("Verified"), findsNWidgets(2));
    });

    testWidgets("Suspend cancels cleanly, then suspends after confirm",
        (tester) async {
      final repo = _StubAdminRepo();
      await _pump(tester, const DriversTab(), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("suspend-11")));
      await tester.pumpAndSettle();
      expect(find.text("Suspend driver"), findsOneWidget);
      expect(repo.suspendCalls, isEmpty);

      await tester.tap(find.byKey(const Key("dialog-cancel")));
      await tester.pumpAndSettle();
      expect(repo.suspendCalls, isEmpty); // dismissed — no dispatch
      expect(find.text("Suspend driver"), findsNothing);

      await tester.tap(find.byKey(const Key("suspend-11")));
      await tester.pumpAndSettle();
      repo.driverRows = List.of(repo.driverRows)
        ..removeWhere((d) => d.driverId == 11)
        ..add(_driver(
          driverId: 11,
          userId: 41,
          name: "Dara",
          email: "dara@taxi.demo",
          active: false,
          online: false,
        ));
      await tester.tap(find.byKey(const Key("dialog-confirm")));
      await tester.pumpAndSettle();

      expect(repo.suspendCalls, [11]);
      expect(find.text("Suspended"), findsNWidgets(2)); // dara joined sophea
      expect(
        tester.widget<FilledButton>(find.byKey(const Key("suspend-11"))).onPressed,
        isNull,
      );
    });
  });

  group("Driver edit sheet", () {
    testWidgets("opens pre-filled and PATCHes all six snake_case fields",
        (tester) async {
      final repo = _StubAdminRepo();
      repo.driverRows[0] = _driver(
        driverId: 11,
        userId: 41,
        name: "Dara",
        email: "dara@taxi.demo",
        phone: "+855 12 345 678",
        carModel: "Honda Dream 125",
        plate: "1KH-2345",
        licenseNo: "KH-9988",
      );
      await _pump(tester, const DriversTab(), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("edit-11")));
      await tester.pumpAndSettle();

      // Modal first — nothing dispatched until Save.
      expect(find.text("Edit driver"), findsOneWidget);
      expect(repo.patchCalls, isEmpty);

      await tester.enterText(
          find.widgetWithText(TextFormField, "Name"), "Dara Sok");
      await tester.enterText(
          find.widgetWithText(TextFormField, r"Price per km ($)"), "2.50");

      await tester.tap(find.text("Save changes"));
      await tester.pumpAndSettle();

      // Record fields asserted separately — map identity inside records.
      expect(repo.patchCalls, hasLength(1));
      expect(repo.patchCalls.single.$1, 11);
      expect(repo.patchCalls.single.$2, <String, dynamic>{
        "name": "Dara Sok",
        "phone": "+855 12 345 678",
        "car_model": "Honda Dream 125",
        "plate": "1KH-2345",
        "license_no": "KH-9988",
        "price_per_km": 2.50,
      });
      // Sheet closed; row re-rendered from server truth + reconcile reload.
      expect(find.text("Edit driver"), findsNothing);
      expect(find.text("Dara Sok"), findsOneWidget);
      expect(find.text(r"$2.50/km"), findsOneWidget);
      expect(repo.driversCalls, 2); // initial load + post-patch reconcile
    });

    testWidgets("an invalid name blocks the PATCH and keeps the sheet open",
        (tester) async {
      final repo = _StubAdminRepo();
      await _pump(tester, const DriversTab(), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("edit-11")));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, "Name"), "D");
      await tester.tap(find.text("Save changes"));
      await tester.pumpAndSettle();

      expect(find.text("At least 2 characters"), findsOneWidget);
      expect(find.text("Edit driver"), findsOneWidget); // still open
      expect(repo.patchCalls, isEmpty);
    });
  });

  group("RidesTab", () {
    testWidgets("renders the feed with status labels", (tester) async {
      final repo = _StubAdminRepo();
      repo.rideRows = [
        _ride(id: 101, status: "completed", driverName: "Dara"),
        _ride(id: 102, status: "requested"),
      ];
      final socket = _FakeSocket();
      await _pump(tester, const RidesTab(),
          repo: repo, rides: _StubRideRepo(), socket: socket);
      await tester.pumpAndSettle();

      expect(socket.connectCalls, 1); // admin session rides one socket
      expect(_badgeText(tester, 101), "Completed");
      expect(_badgeText(tester, 102), "Requested");
      expect(find.textContaining("Central Market"), findsWidgets);
      expect(find.textContaining("Dara"), findsOneWidget);
      expect(repo.statusQueries, [null]); // default filter fetches everything
    });

    testWidgets("filter chips refetch with ?status=", (tester) async {
      final repo = _StubAdminRepo();
      repo.rideRows = [
        _ride(id: 101, status: "completed", driverName: "Dara"),
        _ride(id: 102, status: "requested"),
      ];
      await _pump(tester, const RidesTab(),
          repo: repo, rides: _StubRideRepo(), socket: _FakeSocket());
      await tester.pumpAndSettle();

      // Scope to the chip — the feed badge says the same word — and drag
      // the strip: lazy horizontal lists don't build off-screen chips.
      final chip = find.widgetWithText(ChoiceChip, "Completed");
      await tester.scrollUntilVisible(chip, 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(repo.statusQueries.last, "completed");
      expect(find.byKey(const Key("admin-ride-badge-101")), findsOneWidget);
      expect(find.byKey(const Key("admin-ride-badge-102")), findsNothing);
    });

    testWidgets("socket ride:updated flips a listed ride in place",
        (tester) async {
      final repo = _StubAdminRepo();
      repo.rideRows = [_ride(id: 102, status: "requested")];
      final socket = _FakeSocket();
      await _pump(tester, const RidesTab(),
          repo: repo, rides: _StubRideRepo(), socket: socket);
      await tester.pumpAndSettle();
      expect(_badgeText(tester, 102), "Requested");

      socket.receive("ride:updated", {"rideId": 102, "status": "en_route"});
      await tester.pumpAndSettle();

      expect(_badgeText(tester, 102), "En Route");
    });

    testWidgets("socket ride:updated appends unknown rides from REST",
        (tester) async {
      final repo = _StubAdminRepo();
      repo.rideRows = [];
      final rides = _StubRideRepo()
        ..getByIdResult =
            ApiResult.ok(_ride(id: 300, status: "completed", driverName: "Dara"));
      final socket = _FakeSocket();
      await _pump(tester, const RidesTab(),
          repo: repo, rides: rides, socket: socket);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("admin-ride-badge-300")), findsNothing);

      socket.receive("ride:updated", {"rideId": 300, "status": "completed"});
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("admin-ride-badge-300")), findsOneWidget);
      expect(_badgeText(tester, 300), "Completed");
      expect(find.textContaining("Dara"), findsOneWidget);
    });

    testWidgets("socket append gives up quietly when the fetch fails",
        (tester) async {
      final repo = _StubAdminRepo();
      final rides = _StubRideRepo(); // getById defaults to NOT_FOUND
      repo.rideRows = [_ride(id: 102, status: "requested")];
      final socket = _FakeSocket();
      await _pump(tester, const RidesTab(),
          repo: repo, rides: rides, socket: socket);
      await tester.pumpAndSettle();

      socket.receive("ride:updated", {"rideId": 300, "status": "completed"});
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("admin-ride-badge-300")), findsNothing);
      expect(_badgeText(tester, 102), "Requested"); // feed untouched
    });

    testWidgets("malformed socket announcements are ignored",
        (tester) async {
      final repo = _StubAdminRepo();
      repo.rideRows = [_ride(id: 102, status: "requested")];
      final socket = _FakeSocket();
      await _pump(tester, const RidesTab(),
          repo: repo, rides: _StubRideRepo(), socket: socket);
      await tester.pumpAndSettle();

      socket.receive("ride:updated", {});
      await tester.pumpAndSettle();

      expect(_badgeText(tester, 102), "Requested");
    });

    testWidgets("pull-to-refresh refetches the feed", (tester) async {
      final repo = _StubAdminRepo();
      repo.rideRows = [_ride(id: 101, status: "completed")];
      await _pump(tester, const RidesTab(),
          repo: repo, rides: _StubRideRepo(), socket: _FakeSocket());
      await tester.pumpAndSettle();
      final callsBefore = repo.statusQueries.length;

      await tester.drag(
          find.byKey(const Key("admin-rides-list")), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(repo.statusQueries.length, callsBefore + 1);
    });
  });

  group("AdminScreen", () {
    testWidgets("the four tabs live in the bottom navigation bar; the header "
        "keeps ADMIN and logout", (tester) async {
      final repo = _StubAdminRepo()
        ..rideRows = [_ride(id: 101, status: "completed", driverName: "Dara")];
      await _pump(tester, const AdminScreen(),
          repo: repo, rides: _StubRideRepo(), socket: _FakeSocket());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text("ADMIN"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Log out"), findsOneWidget);

      // Switching through the bar reaches every tab.
      await tester.tap(find.text("Rides"));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("admin-ride-badge-101")), findsOneWidget);
    });

    testWidgets("keeps the logout affordance and switches tabs",
        (tester) async {
      final repo = _StubAdminRepo();
      await _pump(tester, const AdminScreen(), repo: repo);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, "Log out"), findsOneWidget);
      expect(find.text("Dashboard"), findsOneWidget);

      await tester.tap(find.text("Drivers"));
      await tester.pumpAndSettle();
      expect(find.text("Vuthy"), findsOneWidget);
    });

    testWidgets("Task 6.3 wires the Live Map tab into the shell",
        (tester) async {
      final repo = _StubAdminRepo();
      // Tile stub so the mounted map never touches network.
      await _pump(tester,
          AdminScreen(tileLayer: const SizedBox.shrink()), repo: repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Live Map"));
      await tester.pumpAndSettle();

      // These seeded rows report no lat/lng — nobody qualifies for a pin,
      // so the tab proves wiring via its empty state.
      expect(find.byKey(const Key("live-map-empty")), findsOneWidget);
    });
  });
}
