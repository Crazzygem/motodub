import "package:flutter/material.dart";

/// Placeholder — the driver home (online toggle, requests) lands in Phase 4.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Driver shell", style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
