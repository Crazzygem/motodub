import "dart:math" as math;

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/api/api_client.dart";
import "package:motodub/core/api/driver_repo.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/features/booking/booking_sheet.dart";
import "package:motodub/features/customer/customer_home_screen.dart";
import "package:motodub/features/deck/deck_provider.dart";
import "package:motodub/features/deck/mock_drivers.dart";

const _realFlowSkip =
    "guards the real flow, which does not exist in a USE_MOCK_DRIVERS build";

/// Records nearby() calls so tests can prove the deck skipped the API
/// (mock mode) or went through it exactly once (real mode). Never online.
class _SpyRepo extends DriverRepo {
  _SpyRepo([this.result]) : super(ApiClient(dio: Dio()));

  final ApiResult<List<Driver>>? result;
  int calls = 0;
  double? lat;
  double? lng;

  @override
  Future<ApiResult<List<Driver>>> nearby({
    required double lat,
    required double lng,
  }) async {
    calls++;
    this.lat = lat;
    this.lng = lng;
    return result ?? ApiResult.err("NETWORK", "spy: no result scripted");
  }
}

const _fakeDriver = Driver(
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

/// The real build() logic with the dev switch forced on — exercises the
/// actual mock branch, not a fake deck.
class _MockModeDeck extends DeckNotifier {
  @override
  bool get mockMode => true;
}

Future<DeckState> _readDeck(List<Override> overrides) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(deckProvider.future);
}

void main() {
  group("deck provider", () {
    test("mock mode loads five scripted drivers and never calls the repo",
        () async {
      final spy = _SpyRepo();

      final deck = await _readDeck([
        driverRepoProvider.overrideWithValue(spy),
        deckProvider.overrideWith(_MockModeDeck.new),
      ]);

      expect(spy.calls, 0);
      expect(deck.cards.length, 5);
      expect(deck.cards.map((d) => d.id).toSet().length, 5); // unique ids
      expect(deck.swipedLeft, isEmpty);
    });

    test("mock cards are believable: Khmer names, PP coords, sane fields",
        () async {
      final deck = await _readDeck([
        driverRepoProvider.overrideWithValue(_SpyRepo()),
        deckProvider.overrideWith(_MockModeDeck.new),
      ]);

      var previousKm = -1.0;
      for (final d in deck.cards) {
        expect(d.name, isNotNull);
        expect(d.carModel, isNotEmpty);
        expect(d.plate, isNotEmpty);
        expect(d.online, isTrue);
        expect(d.verified, isTrue);
        expect(d.rating, inInclusiveRange(4.5, 5.0));
        expect(d.pricePerKm, inInclusiveRange(0.90, 1.50));

        // Flat distance from the Phnom Penh fallback fix (fine at ≤ 2 km).
        final dLat = (d.lat! - phnomPenhCenter.lat) * 110.57;
        final dLng = (d.lng! - phnomPenhCenter.lng) * 109.06;
        final km = math.sqrt(dLat * dLat + dLng * dLng);
        expect(km, lessThanOrEqualTo(2.05), reason: "${d.name} is too far");
        // Deck sorts by distance, and ETA matches a 12–18 km/h city moto.
        expect(km, greaterThan(previousKm), reason: "${d.name} out of order");
        previousKm = km;
        expect(
          d.etaMinutes!,
          inInclusiveRange(km * 60 / 18 - .01, km * 60 / 12),
          reason: "${d.name} ETA inconsistent with its coords",
        );
      }
    });

    test("flag off (default): provider still loads through the real repo",
        () async {
      final repo = _SpyRepo(ApiResult.ok([_fakeDriver]));

      final deck = await _readDeck([
        driverRepoProvider.overrideWithValue(repo),
      ]);

      expect(repo.calls, 1);
      expect(repo.lat, phnomPenhCenter.lat);
      expect(repo.lng, phnomPenhCenter.lng);
      expect(deck.cards.single.id, 1);
    }, skip: useMockDrivers ? _realFlowSkip : false);

    test("mock mode: refresh reloads the script and stays fully offline",
        () async {
      final spy = _SpyRepo();
      final container = ProviderContainer(overrides: [
        driverRepoProvider.overrideWithValue(spy),
        deckProvider.overrideWith(_MockModeDeck.new),
      ]);
      addTearDown(container.dispose);

      await container.read(deckProvider.future);
      container
          .read(deckProvider.notifier)
          .swipeLeft(container.read(deckProvider).value!.cards.first);
      expect(container.read(deckProvider).value!.cards.length, 4);

      container.read(deckProvider.notifier).refresh();
      final reloaded = await container.read(deckProvider.future);

      expect(reloaded.cards.length, 5); // full script back
      expect(reloaded.swipedLeft, isEmpty); // fresh session
      expect(spy.calls, 0);
    });
  });

  group("customer home", () {
    Future<void> pumpHome(WidgetTester tester, List<Override> overrides) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: CustomerHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        "mock mode: swipe-right pops the card but never opens the booking sheet",
        (tester) async {
      final spy = _SpyRepo();
      await pumpHome(tester, [
        driverRepoProvider.overrideWithValue(spy),
        deckProvider.overrideWith(_MockModeDeck.new),
      ]);
      expect(find.text("Sok Dara"), findsOneWidget); // top mock card

      await tester.fling(find.text("Sok Dara"), const Offset(500, 0), 3000);
      await tester.pumpAndSettle();

      expect(find.byType(BookingSheet), findsNothing);
      expect(find.text("Confirm booking"), findsNothing);
      expect(find.text("Chan Sopheak"), findsOneWidget); // deck popped on
      expect(find.text("Sok Dara"), findsNothing);
      expect(spy.calls, 0);
    });

    // testWidgets.skip is bool-only, so the real-flow guard registers
    // conditionally instead — meaningless in a USE_MOCK_DRIVERS build.
    if (!useMockDrivers) {
      testWidgets("real mode: swipe-right still opens the booking sheet",
          (tester) async {
        await pumpHome(tester, [
          driverRepoProvider.overrideWithValue(
            _SpyRepo(ApiResult.ok([_fakeDriver])),
          ),
        ]);
        expect(find.text("Dara Sok"), findsOneWidget);

        await tester.fling(find.text("Dara Sok"), const Offset(500, 0), 3000);
        await tester.pumpAndSettle();

        expect(find.byType(BookingSheet), findsOneWidget);
        expect(find.text("Confirm booking"), findsOneWidget);
      });
    }
  });
}
