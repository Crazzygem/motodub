import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/auth/auth_state.dart";
import "../booking/booking_sheet.dart";
import "../deck/swipe_deck.dart";

/// Customer landing page — the swipe deck IS the home (Task 3.5 wiring
/// bridge). Right-swipe hands the driver to the booking confirm sheet.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SwipeDeck(
          onSwipedRight: (driver) => showBookingSheet(context, driver),
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
