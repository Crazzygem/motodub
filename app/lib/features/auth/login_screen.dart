import "package:flutter/material.dart";

/// Placeholder — replaced by the real auth flow in Task 1.4.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("MotoDub", style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text("Login arrives in Phase 1",
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
