import "package:flutter/material.dart";

/// Placeholder — the customer swipe deck lands in Phase 3.
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Customer shell",
            style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
