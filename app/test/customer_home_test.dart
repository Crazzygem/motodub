import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/ride_repo.dart";
import "package:motodub/core/auth/auth_state.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/core/router/app_router.dart";
import "package:motodub/features/booking/booking_provider.dart"
    show rideRepoProvider;
import "package:motodub/features/customer/customer_home_screen.dart";
import "package:motodub/features/deck/deck_provider.dart";
import "package:motodub/features/deck/swipe_deck.dart";

const _dara = Driver(
  id: 1,
  userId: 10,
  carModel: "Honda Dream",
  plate: "PP-1A-2345",
  licenseNo: "L-0001",
  verified: true,
  online: true,
  pricePerKm: 1.20,
  name: "Dara Sok",
  rating: 4.8,
  etaMinutes: 4,
);

/// Fixed card list — bypasses HTTP entirely (swipe_deck_test convention).
class _FakeDeck extends DeckNotifier {
  _FakeDeck(this.cards);

  final List<Driver> cards;

  @override
  Future<DeckState> build() async =>
      DeckState(cards: List.of(cards), swipedLeft: const <int>{});
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

const _session = AuthState(
  token: "jwt",
  role: "customer",
  name: "Dara Sok",
  email: "dara@taxi.demo",
);

/// Canned rides/mine — the History tab fetches through this seam.
class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(ApiClient(dio: Dio()));

  ApiResult<List<Ride>>? mineResult;
  int mineCalls = 0;

  @override
  Future<ApiResult<List<Ride>>> mine() async {
    mineCalls++;
    return mineResult ?? const ApiResult.ok([]);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  _StubRideRepo? rideRepo,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deckProvider.overrideWith(() => _FakeDeck([_dara])),
        authProvider.overrideWith(() => _SpyAuth(_session)),
        rideRepoProvider.overrideWithValue(rideRepo ?? _StubRideRepo()),
      ],
      child: const MaterialApp(home: CustomerHomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("customer home renders the SwipeDeck as its landing page",
      (tester) async {
    await _pump(tester);

    expect(find.byType(SwipeDeck), findsOneWidget);
    expect(find.text("Dara Sok"), findsOneWidget);
  });

  testWidgets("greets the session's first name and shows no deck hints",
      (tester) async {
    await _pump(tester);

    // Time-aware greeting carries the first word of the session name and
    // the subtitle sits under it.
    final greeting = tester
        .widget<Text>(find.textContaining("Good "))
        .data!;
    expect(greeting, startsWith("Good "));
    expect(greeting, endsWith(", Dara"));
    expect(find.text("Find your ride below"), findsOneWidget);

    // The old gesture hint chips are gone from the deck header.
    expect(find.text("Swipe right to book"), findsNothing);
    expect(find.text("Left to pass"), findsNothing);
    expect(find.byIcon(Icons.swipe_right_rounded), findsNothing);
    expect(find.byIcon(Icons.swipe_left_rounded), findsNothing);
  });

  testWidgets("greetingFor picks the right time of day and first name",
      (tester) async {
    expect(greetingFor(DateTime(2026, 8, 23, 9), "Dara Sok"),
        "Good morning, Dara");
    expect(greetingFor(DateTime(2026, 8, 23, 14), "Dara Sok"),
        "Good afternoon, Dara");
    expect(greetingFor(DateTime(2026, 8, 23, 20), "Dara Sok"),
        "Good evening, Dara");
    expect(greetingFor(DateTime(2026, 8, 23, 9), null), "Good morning");
    expect(greetingFor(DateTime(2026, 8, 23, 9), "  "), "Good morning");
  });

  testWidgets("bottom navigation offers Deck / History / Account and drops "
      "the old top-right cluster", (tester) async {
    await _pump(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.descendant(
        of: find.byType(NavigationBar), matching: find.text("Deck")),
        findsOneWidget);
    expect(find.descendant(
        of: find.byType(NavigationBar), matching: find.text("History")),
        findsOneWidget);
    expect(find.descendant(
        of: find.byType(NavigationBar), matching: find.text("Account")),
        findsOneWidget);

    // No more history icon or logout pill next to the greeting.
    expect(find.text("Log out"), findsNothing);
    expect(find.byTooltip("Your rides"), findsNothing);
  });

  testWidgets("the History destination swaps in the rides screen", (tester) async {
    final rideRepo = _StubRideRepo()..mineResult = const ApiResult.ok([]);
    await _pump(tester, rideRepo: rideRepo);

    await tester.tap(find.text("History"));
    await tester.pumpAndSettle();

    expect(find.text("Your rides"), findsOneWidget);
    expect(rideRepo.mineCalls, 1);
    expect(find.text("No rides yet"), findsOneWidget);
  });

  testWidgets("the Account destination shows the session identity and the "
      "logout button", (tester) async {
    await _pump(tester);

    await tester.tap(find.text("Account"));
    await tester.pumpAndSettle();

    expect(find.text("Dara Sok"), findsOneWidget);
    expect(find.text("dara@taxi.demo"), findsOneWidget);
    expect(find.text("CUSTOMER"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "Log out"), findsOneWidget);
  });

  testWidgets("logout moves through the Account tab and lands on the login "
      "screen through the router redirect", (tester) async {
    final auth = _SpyAuth(_session);
    final container = ProviderContainer(overrides: [
      deckProvider.overrideWith(() => _FakeDeck([_dara])),
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

    expect(find.byType(SwipeDeck), findsOneWidget); // session → /customer

    await tester.tap(find.text("Account"));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, "Log out"), findsOneWidget);

    await tester.tap(find.text("Log out"));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(SwipeDeck), findsNothing);
    expect(find.widgetWithText(FilledButton, "Log in"), findsOneWidget);
  });
}
