import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/app.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("app boots to the login screen", (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MotoDubApp()));
    await pump(tester);

    expect(find.text("MotoDub"), findsOneWidget);
    expect(find.text("Sign in to book a ride"), findsOneWidget);
    expect(find.text("Log in"), findsOneWidget);
  });

  testWidgets("login shows validation errors for empty/invalid input",
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MotoDubApp()));
    await pump(tester);

    await tester.enterText(find.widgetWithText(TextFormField, "Email"), "bad");
    // leave password empty
    await tester.tap(find.text("Log in"));
    await pump(tester);

    expect(find.text("Enter a valid email"), findsOneWidget);
    expect(find.text("Enter your password"), findsOneWidget);
  });
}

/// One frame for route resolution + one microtask pass for prefs load.
Future<void> pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
