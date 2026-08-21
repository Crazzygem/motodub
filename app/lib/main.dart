import "package:flutter/material.dart";

void main() {
  runApp(const MotoDubApp());
}

/// Bare placeholder — replaced by the themed app shell in Task 0.5.
class MotoDubApp extends StatelessWidget {
  const MotoDubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MotoDub",
      home: Scaffold(
        body: Center(
          child: Text(
            "MotoDub",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}
