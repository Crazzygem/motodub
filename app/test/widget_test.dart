import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/app.dart";

void main() {
  testWidgets("app boots to the login placeholder", (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MotoDubApp()));
    await tester.pumpAndSettle();

    expect(find.text("MotoDub"), findsOneWidget);
    expect(find.text("Login arrives in Phase 1"), findsOneWidget);
  });
}
