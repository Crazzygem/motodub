import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../customer/customer_home_screen.dart";

/// Placeholder — the admin dashboard lands in Phase 6.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Admin shell", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const LogoutButton(),
          ],
        ),
      ),
    );
  }
}
