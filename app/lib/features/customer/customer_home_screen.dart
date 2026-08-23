import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/auth/auth_state.dart";
import "../booking/booking_sheet.dart";
import "../deck/deck_provider.dart";
import "../deck/swipe_deck.dart";

/// Customer landing page — the swipe deck IS the home (Task 3.5 wiring
/// bridge). Right-swipe hands the driver to the booking confirm sheet.
/// The slim top bar only carries the history entry point (Task 5.2).
/// In mock-driver mode (USE_MOCK_DRIVERS) the sheet is skipped: a mock
/// driverId would 404 on the real API, so the card just flies off.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockMode = ref.watch(deckProvider.notifier).mockMode;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => context.push("/history"),
                icon: const Icon(Icons.history_rounded),
                tooltip: "Your rides",
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
      ),
    );
  }
}

/// Shared logout pill used by every role shell.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.tonal(
      onPressed: () => ref.read(authProvider.notifier).logout(),
      child: const Text("Log out"),
    );
  }
}
