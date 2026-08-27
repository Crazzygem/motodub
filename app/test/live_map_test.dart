import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:duboun/core/api/admin_repo.dart";
import "package:duboun/core/api/api_client.dart";
import "package:duboun/core/api/error_messages.dart";
import "package:duboun/features/admin/admin_screen.dart"
    show adminRepoProvider;
import "package:duboun/features/admin/live_map_tab.dart";

// Task 6.3 — admin live map: flutter_map of Phnom Penh fed by a ~10s poll of
// GET /api/admin/drivers; pins only for verified+online drivers that carry a
// heartbeat position, tap reveals name/car/plate/rating.
//
// Isolation: repo subclasses the real one over a dead Dio client; the tile
// layer is a stub so nothing touches network — same convention as
// tracking_test / admin_test.
AdminDriver _driver({
  required int driverId,
  required String name,
  bool verified = true,
  bool online = true,
  double rating = 4.8,
  double? lat = 11.562,
  double? lng = 104.918,
}) =>
    AdminDriver(
      driverId: driverId,
      userId: 40 + driverId,
      name: name,
      email: "$name@taxi.demo",
      rating: rating,
      active: true,
      pricePerKm: 1.2,
      verified: verified,
      online: online,
      carModel: "Toyota Highlander SUV",
      plate: "PP-1A-$driverId",
      lat: lat,
      lng: lng,
    );

ApiClient _deadClient() => ApiClient(dio: Dio());

class _StubAdminRepo extends AdminRepo {
  _StubAdminRepo() : super(_deadClient());

  List<AdminDriver> rows = const <AdminDriver>[];
  ApiResult<List<AdminDriver>> result =
      ApiResult.ok(const <AdminDriver>[]);

  int calls = 0;

  @override
  Future<ApiResult<List<AdminDriver>>> drivers() async {
    calls++;
    return result.isOk ? ApiResult.ok(List.of(rows)) : result;
  }
}

const _tileLayer = SizedBox.shrink();

Future<void> _pump(
  WidgetTester tester,
  _StubAdminRepo repo,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminRepoProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: Scaffold(body: LiveMapTab(tileLayer: _tileLayer)),
      ),
    ),
  );
}

void main() {
  group("LiveMapTab", () {
    testWidgets("pins only verified online drivers that have a position",
        (tester) async {
      final repo = _StubAdminRepo()
        ..rows = [
          _driver(driverId: 11, name: "Dara"),
          _driver(driverId: 12, name: "Sophea"),
          // Unverified AND offline — excluded twice over.
          _driver(driverId: 33, name: "Vuthy", verified: false, online: false),
          // Online+verified but never reported a position — unpinnable.
          _driver(driverId: 14, name: "Rithy", lat: null, lng: null),
        ];
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("map-pin-11")), findsOneWidget);
      expect(find.byKey(const Key("map-pin-12")), findsOneWidget);
      expect(find.byKey(const Key("map-pin-33")), findsNothing);
      expect(find.byKey(const Key("map-pin-14")), findsNothing);
    });

    testWidgets("excludes offline and unverified drivers", (tester) async {
      final repo = _StubAdminRepo()
        ..rows = [
          _driver(driverId: 11, name: "Dara"),
          _driver(driverId: 21, name: "Gone offline", online: false),
          _driver(driverId: 22, name: "Not yet approved", verified: false),
        ];
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("map-pin-11")), findsOneWidget);
      expect(find.byKey(const Key("map-pin-21")), findsNothing);
      expect(find.byKey(const Key("map-pin-22")), findsNothing);
    });

    testWidgets("tapping a pin shows the driver card", (tester) async {
      final repo = _StubAdminRepo()
        ..rows = [_driver(driverId: 11, name: "Dara")];
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text("Dara"), findsNothing);
      await tester.tap(find.byKey(const Key("map-pin-11")));
      await tester.pumpAndSettle();

      expect(find.text("Dara"), findsOneWidget);
      expect(find.text("Toyota Highlander SUV · PP-1A-11"), findsOneWidget);
      expect(find.text("★ 4.8"), findsOneWidget);

      await tester.tap(find.byKey(const Key("pin-card-close")));
      await tester.pumpAndSettle();
      expect(find.text("Dara"), findsNothing);
    });

    testWidgets("polls GET /api/admin/drivers every 10 seconds",
        (tester) async {
      final repo = _StubAdminRepo()
        ..rows = [_driver(driverId: 11, name: "Dara")];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(repo.calls, 1); // immediate boot fetch

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(repo.calls, 3);

      // Leaving the tab cancels the timer — no further polls, no crash.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(repo.calls, 3);
    });

    testWidgets("shows an empty state when nobody qualifies",
        (tester) async {
      final repo = _StubAdminRepo()
        ..rows = [_driver(driverId: 33, name: "Vuthy", online: false)];
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("live-map-empty")), findsOneWidget);
      expect(find.text("No online drivers right now"), findsOneWidget);
    });

    testWidgets("first-load failure shows a mapped error, retry recovers",
        (tester) async {
      final repo = _StubAdminRepo()
        ..result = const ApiResult.err("NETWORK", networkUnreachableMessage)
        ..rows = [_driver(driverId: 11, name: "Dara")];
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text(networkUnreachableMessage), findsOneWidget);
      expect(find.byKey(const Key("map-pin-11")), findsNothing);

      repo.result = ApiResult.ok(List.of(repo.rows));
      await tester.tap(find.text("Try again"));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("map-pin-11")), findsOneWidget);
    });

    testWidgets("a failed refresh keeps last good pins silently",
        (tester) async {
      final repo = _StubAdminRepo()
        ..rows = [_driver(driverId: 11, name: "Dara")];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("map-pin-11")), findsOneWidget);

      repo.result = const ApiResult.err("NETWORK", networkUnreachableMessage);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("map-pin-11")), findsOneWidget); // retained
      expect(find.text(networkUnreachableMessage), findsNothing); // silent
      expect(find.text("Try again"), findsNothing);
    });
  });
}
