import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/features/customer/customer_home_screen.dart";
import "package:motodub/features/deck/deck_provider.dart";
import "package:motodub/features/deck/swipe_deck.dart";

/// Fixed card list — bypasses HTTP entirely (swipe_deck_test convention).
class _FakeDeck extends DeckNotifier {
  _FakeDeck(this.cards);

  final List<Driver> cards;

  @override
  Future<DeckState> build() async =>
      DeckState(cards: List.of(cards), swipedLeft: const <int>{});
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
}
