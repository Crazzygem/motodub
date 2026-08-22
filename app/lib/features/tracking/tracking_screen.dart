import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Placeholder for Task 5.1 — proves the booking flow can land on a tracking
/// route with the created ride id (Task 3.5 step 4).
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.rideId});

  final int rideId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🛵", style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text("Ride #$rideId requested",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              "Waiting for your driver to respond — live tracking lands in Phase 5.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => context.go("/customer"),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text("Back to deck"),
            ),
          ],
        ),
      ),
    );
  }
}
