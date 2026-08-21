import "package:flutter_test/flutter_test.dart";
import "package:motodub/main.dart";

void main() {
  testWidgets("placeholder app renders", (tester) async {
    await tester.pumpWidget(const MotoDubApp());

    expect(find.text("MotoDub"), findsOneWidget);
  });
}
