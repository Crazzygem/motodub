import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../customer/customer_home_screen.dart";

/// Placeholder — the driver home (online toggle, requests) lands in Phase 4.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Driver shell",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const LogoutButton(),
          ],
        ),
      ),
    );
  }
}
