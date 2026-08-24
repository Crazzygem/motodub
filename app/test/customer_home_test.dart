import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/auth/auth_state.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/core/router/app_router.dart";
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
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deckProvider.overrideWith(() => _FakeDeck([_dara])),
        authProvider.overrideWith(() => _SpyAuth(_session)),
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

  testWidgets("greets the session's first name and shows the deck hints",
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

    // Gesture hint chips (green right / red left) under the deck header.
    expect(find.text("Swipe right to book"), findsOneWidget);
    expect(find.text("Left to pass"), findsOneWidget);
    expect(find.byIcon(Icons.swipe_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swipe_left_rounded), findsOneWidget);
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

  testWidgets("logout dispatches the auth logout and lands on the login "
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

    await tester.tap(find.text("Log out"));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(SwipeDeck), findsNothing);
    expect(find.widgetWithText(FilledButton, "Log in"), findsOneWidget);
  });
}
