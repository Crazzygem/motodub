import "package:flutter/material.dart";

/// Placeholder — the admin dashboard lands in Phase 6.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Admin shell", style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
