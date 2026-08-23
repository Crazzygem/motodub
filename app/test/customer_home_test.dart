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

void main() {
  testWidgets("customer home renders the SwipeDeck as its landing page",
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deckProvider.overrideWith(() => _FakeDeck([
                const Driver(
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
                ),
              ])),
        ],
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SwipeDeck), findsOneWidget);
    expect(find.text("Dara Sok"), findsOneWidget);
  });

  testWidgets("logout dispatches the auth logout and lands on the login "
      "screen through the router redirect", (tester) async {
    final auth = _SpyAuth(const AuthState(token: "jwt", role: "customer"));
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
