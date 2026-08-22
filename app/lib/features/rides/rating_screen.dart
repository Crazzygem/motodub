import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Placeholder for Task 7.1 — proves the completed-ride handoff can land on
/// a rating route with the ride id (Task 5.1 step 4).
class RatingScreen extends StatelessWidget {
  const RatingScreen({super.key, required this.rideId});

  final int rideId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("⭐", style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text("Rate ride #$rideId",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              "Rating flow lands in Task 7.1.",
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
