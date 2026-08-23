import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/driver_repo.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/api/socket_client.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/core/theme/app_theme.dart";
import "package:motodub/features/booking/booking_provider.dart"
    show rideRepoProvider;
import "package:motodub/features/deck/deck_provider.dart" show driverRepoProvider;
import "package:motodub/features/driver/driver_home_screen.dart";
import "package:motodub/features/driver/driver_provider.dart";
import "package:motodub/features/rides/rating_screen.dart";
import "package:motodub/features/tracking/tracking_screen.dart";

// Task 7.1 — rating screens: party header, tap-to-select stars, POST
// /api/rides/{id}/rate {stars}, thanks state, already-rated → thanks without
// error, mapped error banner + retry, and the completed handoffs from BOTH
// sides (tracking provider for the customer, driver provider for the driver).
//
// Isolation: repos subclass the real ones over a dead Dio client; the socket
// is a no-network double fed through handleEvent (same convention as
// tracking_test / driver_home_test).
Ride _ride(String status) => const Ride(
      id: 100,
      customerId: 9,
      driverId: 40,
      status: "completed",
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
      customerName: "Srey",
      driverName: "Dara",
    );

ApiClient _deadClient() => ApiClient(dio: Dio());

/// Serves canned results and records every rate dispatch.
class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(_deadClient());

  ApiResult<Ride> getByIdResult = ApiResult.ok(_ride("completed"));
  ApiResult<Ride>? rateResult;
  ApiResult<Ride>? actResult;

  final List<(int, int)> rateCalls = <(int, int)>[];
  final List<(int, RideAction)> actCalls = <(int, RideAction)>[];

  @override
  Future<ApiResult<Ride>> getById(int id) async => getByIdResult;

  @override
  Future<ApiResult<Ride>> act(int id, RideAction action) async {
    actCalls.add((id, action));
    return actResult ?? ApiResult.ok(_ride("completed"));
  }

  @override
  Future<ApiResult<Ride>> rate(int id, {required int stars}) async {
    rateCalls.add((id, stars));
    return rateResult ?? ApiResult.ok(_ride("completed"));
  }
}

/// No-network socket double that replays typed events.
class _FakeSocket extends SocketClient {
  _FakeSocket() : super(baseUrl: "http://127.0.0.1:1", token: "jwt");

  @override
  void connect() {}

  void receive(String event, Map<String, dynamic> payload) =>
      handleEvent(event, payload);
}

/// Seeds the driver home provider without any REST/socket bootstrap.
class _SeededDriverHome extends DriverNotifier {
  _SeededDriverHome(this.seed);

  final DriverHomeState seed;

  @override
  Future<DriverHomeState> build() async => seed;
}

Future<void> _pumpRating(WidgetTester tester, _StubRideRepo repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: "/rating/100",
    routes: [
      GoRoute(
        path: "/rating/:rideId",
        builder: (_, state) => RatingScreen(
          rideId: int.parse(state.pathParameters["rideId"]!),
          viewerRole: "customer",
        ),
      ),
      GoRoute(
        path: "/customer",
        builder: (_, _) => const Scaffold(body: Text("deck")),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [rideRepoProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  group("RatingScreen", () {
    late _StubRideRepo repo;

    setUp(() => repo = _StubRideRepo());

    testWidgets("renders the other party and five tappable stars",
        (tester) async {
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text("Dara"), findsOneWidget); // customer rates the driver
      expect(find.text("Srey"), findsNothing);
      expect(find.byKey(const Key("star-1")), findsOneWidget);
      expect(find.byKey(const Key("star-2")), findsOneWidget);
      expect(find.byKey(const Key("star-3")), findsOneWidget);
      expect(find.byKey(const Key("star-4")), findsOneWidget);
      expect(find.byKey(const Key("star-5")), findsOneWidget);

      // Nothing selected yet → submit stays honest (disabled).
      final submit =
          tester.widget<FilledButton>(find.byKey(const Key("rating-submit")));
      expect(submit.onPressed, isNull);
    });

    testWidgets("tapping star N selects N and arms the submit button",
        (tester) async {
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("star-3")));
      await tester.pump();

      Color colorOf(int n) => tester
          .widget<Icon>(find.byKey(Key("star-$n")))
          .color!;
      expect(colorOf(1), ratingStarColor);
      expect(colorOf(2), ratingStarColor);
      expect(colorOf(3), ratingStarColor);
      expect(colorOf(4), AppColors.line);
      expect(colorOf(5), AppColors.line);

      final submit =
          tester.widget<FilledButton>(find.byKey(const Key("rating-submit")));
      expect(submit.onPressed, isNotNull);
    });

    testWidgets("submit dispatches POST /api/rides/{id}/rate {stars:N}",
        (tester) async {
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("star-4")));
      await tester.pump();
      await tester.tap(find.byKey(const Key("rating-submit")));
      await tester.pump();

      expect(repo.rateCalls, [(100, 4)]);
    });

    testWidgets("success flips to the thanks state", (tester) async {
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("star-5")));
      await tester.pump();
      await tester.tap(find.byKey(const Key("rating-submit")));
      await tester.pump();

      expect(find.text("Thanks!"), findsOneWidget);
      // The auto-exit timer pops back to the deck after a beat.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text("deck"), findsOneWidget);
    });

    testWidgets("an already-rated verdict shows thanks WITHOUT an error",
        (tester) async {
      repo.rateResult = const ApiResult.err(
        "RIDE_INVALID_TRANSITION",
        "That ride can't be updated from its current state.",
      );
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("star-5")));
      await tester.pump();
      await tester.tap(find.byKey(const Key("rating-submit")));
      await tester.pump();

      expect(find.text("Thanks!"), findsOneWidget);
      expect(find.text("You already rated this ride."), findsOneWidget);
      expect(find.byKey(const Key("rating-error-banner")), findsNothing);
    });

    testWidgets("a failed boot surfaces the mapped error and retry recovers",
        (tester) async {
      repo.getByIdResult =
          const ApiResult.err("NETWORK", "Cannot reach server. Is the backend running?");
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load this ride"), findsOneWidget);
      expect(find.text("Cannot reach server. Is the backend running?"),
          findsOneWidget);

      repo.getByIdResult = ApiResult.ok(_ride("completed"));
      await tester.tap(find.text("Try again"));
      await tester.pumpAndSettle();

      expect(find.text("Dara"), findsOneWidget);
    });

    testWidgets(
        "other failures surface the mapped banner and keep the form",
        (tester) async {
      repo.rateResult =
          const ApiResult.err("NETWORK", "Cannot reach server. Is the backend running?");
      await _pumpRating(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("star-5")));
      await tester.pump();
      await tester.tap(find.byKey(const Key("rating-submit")));
      await tester.pump();

      expect(find.byKey(const Key("rating-error-banner")), findsOneWidget);
      expect(find.text("Cannot reach server. Is the backend running?"),
          findsOneWidget);
      expect(find.text("Thanks!"), findsNothing);
      // Selection persists → retrying is just another submit tap.
      final submit =
          tester.widget<FilledButton>(find.byKey(const Key("rating-submit")));
      expect(submit.onPressed, isNotNull);
    });
  });

  group("completed handoffs", () {
    late _StubRideRepo repo;

    setUp(() => repo = _StubRideRepo());

    GoRouter buildRouter(String initial, List<GoRoute> routes) => GoRouter(
          initialLocation: initial,
          routes: routes,
        );

    void setSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
    }

    testWidgets(
        "customer side: a live completed transition in trackingProvider "
        "navigates to /rating/{rideId}", (tester) async {
      setSize(tester);
      final socket = _FakeSocket();
      repo.getByIdResult = ApiResult.ok(Ride(
        id: 100,
        customerId: 9,
        driverId: 40,
        status: "in_progress",
        pickupLat: 11.5564,
        pickupLng: 104.9282,
        pickupAddress: "Central Market",
        dropoffLat: 11.5449,
        dropoffLng: 104.8922,
        dropoffAddress: "Airport",
        driverName: "Dara",
      ));

      final router = buildRouter("/tracking/100", [
        GoRoute(
          path: "/tracking/:rideId",
          builder: (_, state) => TrackingScreen(
            rideId: int.parse(state.pathParameters["rideId"]!),
            tileLayer: const SizedBox.shrink(),
          ),
        ),
        GoRoute(
          path: "/rating/:rideId",
          builder: (_, _) => const Scaffold(body: Text("rating-screen")),
        ),
        GoRoute(
          path: "/customer",
          builder: (_, _) => const Scaffold(body: Text("deck")),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRepoProvider.overrideWithValue(repo),
            socketClientProvider.overrideWithValue(socket),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("rating-screen"), findsNothing);

      socket.receive("ride:updated", {"rideId": 100, "status": "completed"});
      await tester.pumpAndSettle();

      // Handoff landed on the /rating/{id} route (content itself is
      // covered by the RatingScreen group above).
      expect(find.text("rating-screen"), findsOneWidget);
    });

    testWidgets(
        "driver side: completing the active ride navigates to "
        "/rating/{rideId}", (tester) async {
      setSize(tester);
      final active = Ride(
        id: 100,
        customerId: 9,
        driverId: 40,
        status: "in_progress",
        pickupLat: 11.5564,
        pickupLng: 104.9282,
        pickupAddress: "Central Market",
        dropoffLat: 11.5449,
        dropoffLng: 104.8922,
        dropoffAddress: "Airport",
        customerName: "Srey",
      );

      final router = buildRouter("/driver", [
        GoRoute(path: "/driver", builder: (_, _) => const DriverHomeScreen()),
        GoRoute(
          path: "/rating/:rideId",
          builder: (_, state) => RatingScreen(
            rideId: int.parse(state.pathParameters["rideId"]!),
            viewerRole: "driver",
          ),
        ),
        GoRoute(
          path: "/customer",
          builder: (_, _) => const Scaffold(body: Text("deck")),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRepoProvider.overrideWithValue(repo),
            driverRepoProvider.overrideWithValue(_NoDriverRepo()),
            socketClientProvider.overrideWithValue(_FakeSocket()),
            driverProvider.overrideWith(
                () => _SeededDriverHome(DriverHomeState(active: active))),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("End ride ✓"));
      await tester.pumpAndSettle();

      expect(repo.actCalls, [(100, RideAction.complete)]); // the completing call
      expect(repo.rateCalls, isEmpty); // navigation only — no auto-rate
      // The REAL rating screen, fed the driver's opposite party.
      expect(find.text("Rate your trip"), findsOneWidget);
      expect(find.text("Srey"), findsOneWidget);
    });
  });
}

/// Driver profile repo double — the seeded home never reads it, but the
/// provider override still needs a concrete instance.
class _NoDriverRepo extends DriverRepo {
  _NoDriverRepo() : super(_deadClient());
}
