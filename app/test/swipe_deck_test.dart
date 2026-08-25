import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/driver_repo.dart";
import "package:motodub/core/api/error_messages.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/features/deck/deck_provider.dart";
import "package:motodub/features/deck/mock_drivers.dart" show useMockDrivers;
import "package:motodub/features/deck/swipe_deck.dart";

Driver _driver(int id, String name) => Driver(
      id: id,
      userId: id * 10,
      carModel: "Honda Dream",
      plate: "1AB-234$id",
      licenseNo: "L-000$id",
      verified: true,
      online: true,
      pricePerKm: 1.20,
      name: name,
      rating: 4.8,
      etaMinutes: 4,
    );

/// Bypasses HTTP entirely — fixed card list, like the real nearby payload.
class _FakeDeck extends DeckNotifier {
  _FakeDeck(this.cards);

  final List<Driver> cards;

  @override
  Future<DeckState> build() async =>
      DeckState(cards: List.of(cards), swipedLeft: const <int>{});
}

/// Server unreachable / business error — exercises the deck's error state.
class _FailingRepo extends DriverRepo {
  _FailingRepo() : super(_deadClient());

  static ApiClient _deadClient() => ApiClient(dio: Dio());

  @override
  Future<ApiResult<List<Driver>>> nearby({
    required double lat,
    required double lng,
  }) async =>
      ApiResult.err("NETWORK", errorMessageFor("NETWORK"));
}

Widget _harness({
  required List<Driver> cards,
  ValueChanged<Driver>? onSwipedRight,
  ValueChanged<Driver>? onSwipedLeft,
}) {
  return ProviderScope(
    overrides: [deckProvider.overrideWith(() => _FakeDeck(cards))],
    child: MaterialApp(
      home: Scaffold(
        body: SwipeDeck(
          onSwipedRight: onSwipedRight,
          onSwipedLeft: onSwipedLeft,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("fling right pops the top card and fires onSwipedRight",
      (tester) async {
    Driver? booked;
    await tester.pumpWidget(_harness(
      cards: [_driver(1, "Dara Sok"), _driver(2, "Srey Neth")],
      onSwipedRight: (d) => booked = d,
    ));
    await tester.pumpAndSettle();

    await tester.fling(find.text("Dara Sok"), const Offset(500, 0), 3000);
    await tester.pumpAndSettle(); // let the .45s fly-out finish

    expect(booked?.id, 1);
    expect(find.text("Srey Neth"), findsOneWidget); // next card is on top
    expect(find.text("Dara Sok"), findsNothing); // popped off the deck
  });

  testWidgets("fling left fires onSwipedLeft and pops locally", (tester) async {
    Driver? passed;
    await tester.pumpWidget(_harness(
      cards: [_driver(1, "Dara Sok"), _driver(2, "Srey Neth")],
      onSwipedLeft: (d) => passed = d,
    ));
    await tester.pumpAndSettle();

    await tester.fling(find.text("Dara Sok"), const Offset(-500, 0), 3000);
    await tester.pumpAndSettle();

    expect(passed?.id, 1);
    expect(find.text("Srey Neth"), findsOneWidget);
  });

  testWidgets("half drag released under threshold springs back, no callbacks",
      (tester) async {
    var callbacks = 0;
    await tester.pumpWidget(_harness(
      cards: [_driver(1, "Dara Sok"), _driver(2, "Srey Neth")],
      onSwipedRight: (_) => callbacks++,
      onSwipedLeft: (_) => callbacks++,
    ));
    await tester.pumpAndSettle();

    // 55px over 200ms ≈ slow deliberate drag — under both thresholds.
    await tester.timedDrag(
      find.text("Dara Sok"),
      const Offset(55, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle(); // .35s spring-back done

    expect(callbacks, 0);
    expect(find.text("Dara Sok"), findsOneWidget); // never popped
  });

  // Seth directive: BOOK/PASS text stamps replaced by a swipe-direction
  // gradient wash — green toward commit-right, red toward commit-left.
  group("swipe direction wash", () {
    Future<void> pumpDeck(WidgetTester tester) async {
      await tester.pumpWidget(_harness(cards: [_driver(1, "Dara Sok")]));
      await tester.pumpAndSettle();
    }

    /// Drags part-way (under both release thresholds) and renders one frame
    /// mid-wash — the first spring-back frame still carries the full drag.
    Future<void> dragPartWay(WidgetTester tester, Offset delta) async {
      await tester.timedDrag(
        find.text("Dara Sok"),
        delta,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
    }

    LinearGradient washGradient(WidgetTester tester) =>
        (tester.widget<DecoratedBox>(find.descendant(
              of: find.byKey(const Key("deck-swipe-wash")),
              matching: find.byType(DecoratedBox),
            )).decoration as BoxDecoration)
            .gradient! as LinearGradient;

    double washOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find.descendant(
          of: find.byKey(const Key("deck-swipe-wash")),
          matching: find.byType(Opacity),
        ))
        .opacity;

    void expectHue(Color tint, {required bool green}) {
      expect(green ? tint.g : tint.r, greaterThan(tint.b));
      if (green) {
        expect(tint.g, greaterThan(tint.r));
      } else {
        expect(tint.r, greaterThan(tint.g));
      }
    }

    testWidgets("stamp text is gone — no BOOK or PASS anywhere, even mid-drag",
        (tester) async {
      await pumpDeck(tester);
      await dragPartWay(tester, const Offset(100, 0));

      expect(find.text("BOOK"), findsNothing);
      expect(find.text("PASS"), findsNothing);
    });

    testWidgets("wash is invisible at rest", (tester) async {
      await pumpDeck(tester);

      expect(washOpacity(tester), 0);
    });

    testWidgets("right drag washes the card green toward commit", (tester) async {
      await pumpDeck(tester);
      await dragPartWay(tester, const Offset(100, 0));

      expect(washOpacity(tester), greaterThan(.5));
      final gradient = washGradient(tester);
      expectHue(gradient.colors.last, green: true); // leading edge carries tint
      expect(gradient.colors.first.a, 0); // trailing edge stays clear
      await tester.pumpAndSettle(); // spring-back unwinds
      expect(washOpacity(tester), 0);
    });

    testWidgets("left drag washes the card red toward commit", (tester) async {
      await pumpDeck(tester);
      await dragPartWay(tester, const Offset(-100, 0));

      expect(washOpacity(tester), greaterThan(.5));
      final gradient = washGradient(tester);
      expectHue(gradient.colors.last, green: false);
      expect(gradient.colors.first.a, 0);
      await tester.pumpAndSettle();
      expect(washOpacity(tester), 0);
    });
  });

  testWidgets("empty deck shows the friendly empty state", (tester) async {
    await tester.pumpWidget(_harness(cards: []));
    await tester.pumpAndSettle();

    expect(
      find.text("No drivers online right now — pull to refresh"),
      findsOneWidget,
    );
  });

  testWidgets("last card popped leaves the empty state", (tester) async {
    Driver? booked;
    await tester.pumpWidget(_harness(
      cards: [_driver(1, "Dara Sok")],
      onSwipedRight: (d) => booked = d,
    ));
    await tester.pumpAndSettle();

    await tester.fling(find.text("Dara Sok"), const Offset(500, 0), 3000);
    await tester.pumpAndSettle();

    expect(booked?.id, 1);
    expect(
      find.text("No drivers online right now — pull to refresh"),
      findsOneWidget,
    );
  });

  // Real-flow guard — in a USE_MOCK_DRIVERS build the deck never calls the
  // repo, so there is no error state to surface.
  if (!useMockDrivers) {
    testWidgets("server error surfaces the friendly error banner",
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [driverRepoProvider.overrideWithValue(_FailingRepo())],
          child: const MaterialApp(home: Scaffold(body: SwipeDeck())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Cannot reach server. Is the backend running?"),
        findsOneWidget,
      );
      expect(find.text("Retry"), findsOneWidget);
    });
  }
}
