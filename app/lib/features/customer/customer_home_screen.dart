import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/auth/auth_state.dart";
import "../../core/theme/app_theme.dart";
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_rounded),
            label: "Deck",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: "History",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: "Account",
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
    final mockMode = ref.watch(deckProvider.notifier).mockMode;
    final name = ref.watch(authProvider).valueOrNull?.name;
    final greeting = greetingFor(DateTime.now(), name);

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
                Text("Find your ride below",
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // Wrap, not Row — on narrow screens the chips flow onto a
            // second line instead of overflowing the deck header.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _HintChip(
                  icon: Icons.swipe_right_rounded,
                  label: "Swipe right to book",
                  tint: AppColors.bookGreen,
                ),
                _HintChip(
                  icon: Icons.swipe_left_rounded,
                  label: "Left to pass",
                  tint: AppColors.passRed,
                ),
              ],
            ),
          ),
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

/// Small tinted pill explaining the deck gesture (§5 chips).
class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: tint, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
