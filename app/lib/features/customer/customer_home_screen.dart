import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/auth/auth_state.dart";
import "../../core/l10n/l10n.dart";
import "../account/account_screen.dart";
import "../booking/booking_sheet.dart";
import "../deck/deck_provider.dart";
import "../deck/swipe_deck.dart";
import "../rides/history_screen.dart";

/// Time-of-day greeting — "Good morning/afternoon/evening, `<first name>`".
/// First name comes from the session payload; [now] is injectable so tests
/// are deterministic.
String greetingFor(DateTime now, String? name) {
  final part = now.hour < 12
      ? "morning"
      : now.hour < 18
          ? "afternoon"
          : "evening";
  final first = name?.trim().split(RegExp(r"\s+")).first;
  return (first == null || first.isEmpty) ? "Good $part" : "Good $part, $first";
}

/// Localized twin of [greetingFor] used by the deck header.
String localizedGreeting(AppLocalizations s, DateTime now, String? name) {
  final part = now.hour < 12
      ? s.greetingMorning
      : now.hour < 18
          ? s.greetingAfternoon
          : s.greetingEvening;
  final first = name?.trim().split(RegExp(r"\s+")).first;
  return (first == null || first.isEmpty)
      ? part
      : s.greetingWithName(part, first);
}

/// Customer landing shell — the swipe deck IS the home (Task 3.5 wiring
/// bridge), and Deck / History / Account live behind a Material 3 bottom
/// [NavigationBar] (nav restructure). Right-swipe hands the driver to the
/// booking confirm sheet. In mock-driver mode (USE_MOCK_DRIVERS) the sheet
/// is skipped: a mock driverId would 404 on the real API, so the card just
/// flies off.
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      // Conditional swap, not IndexedStack — only the active tab is mounted,
      // so finders and fetches never see hidden tabs.
      body: switch (_tab) {
        1 => const HistoryScreen(),
        2 => const AccountScreen(),
        _ => const _DeckTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.style_rounded),
            label: l10n.navDeck,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_rounded),
            label: l10n.navAccount,
          ),
        ],
      ),
    );
  }
}

class _DeckTab extends ConsumerWidget {
  const _DeckTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mockMode = ref.watch(deckProvider.notifier).mockMode;
    final name = ref.watch(authProvider).valueOrNull?.name;
    final greeting = localizedGreeting(l10n, DateTime.now(), name);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(l10n.findYourRide,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SwipeDeck(
              onSwipedRight: (driver) {
                if (mockMode) return; // mock ids never exist on the API
                showBookingSheet(context, driver);
              },
            ),
          ),
        ],
      ),
    );
  }
}
