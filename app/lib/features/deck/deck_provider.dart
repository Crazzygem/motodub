import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/api_client.dart";
import "../../core/api/driver_repo.dart";
import "../../core/models/driver.dart";
import "../auth/providers.dart" show apiClientProvider;
import "mock_drivers.dart" show mockDrivers, useMockDrivers;

/// Phnom Penh center — the deck's location fallback (PROJECT/ARCH §8).
const ({double lat, double lng}) phnomPenhCenter =
    (lat: 11.5564, lng: 104.9282);

/// Device GPS fix when a location plugin is wired; null → PP center fallback.
Future<({double lat, double lng})?> devicePosition() async => null;

final driverRepoProvider = Provider<DriverRepo>(
  (ref) => DriverRepo(ref.watch(apiClientProvider)),
);

/// Deck snapshot: remaining cards + drivers passed this session (local only).
class DeckState {
  const DeckState({required this.cards, required this.swipedLeft});

  final List<Driver> cards;
  final Set<int> swipedLeft; // driver ids passed — never sent to the server
}

/// Loads `GET /drivers/nearby` around the current fix and pops cards as they
/// are swiped away. Swipe-left is session-local; swipe-right only pops here —
/// booking itself is driven by SwipeDeck's onSwipedRight callback (Task 3.5).
class DeckNotifier extends AsyncNotifier<DeckState> {
  /// Dev seam (USE_MOCK_DRIVERS): true skips the API for a scripted deck and
  /// tells CustomerHomeScreen to skip booking. Overridable in tests.
  bool get mockMode => useMockDrivers;

  @override
  Future<DeckState> build() async {
    if (mockMode) {
      return DeckState(cards: List.of(mockDrivers), swipedLeft: const <int>{});
    }
    final fix = await devicePosition();
    final pos = fix ?? phnomPenhCenter;
    final result = await ref.watch(driverRepoProvider).nearby(
          lat: pos.lat,
          lng: pos.lng,
        );
    if (!result.isOk) {
      throw ApiException(result.code ?? "INTERNAL", result.message ?? "");
    }
    return DeckState(cards: result.data ?? [], swipedLeft: const <int>{});
  }

  /// BOOK — pop the card; the widget's callback takes it from here.
  void swipeRight(Driver driver) => _pop(driver.id);

  /// PASS — pop locally and remember for this session only.
  void swipeLeft(Driver driver) {
    _pop(driver.id);
    final swiped = {...(state.value?.swipedLeft ?? <int>{})};
    swiped.add(driver.id);
    state = AsyncData(
      DeckState(cards: state.value?.cards ?? [], swipedLeft: swiped),
    );
  }

  void refresh() => ref.invalidateSelf();

  void _pop(int driverId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      DeckState(
        cards: current.cards.where((d) => d.id != driverId).toList(),
        swipedLeft: current.swipedLeft,
      ),
    );
  }
}

final deckProvider =
    AsyncNotifierProvider<DeckNotifier, DeckState>(DeckNotifier.new);
