import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/models/driver.dart";
import "package:motodub/features/deck/driver_card.dart";

Driver _sampleDriver() => const Driver(
      id: 1,
      userId: 11,
      carModel: "Honda Dream",
      plate: "1AB-2345",
      licenseNo: "L-0001",
      verified: true,
      online: true,
      pricePerKm: 1.20,
      name: "Dara Sok",
      photo: "https://example.com/dara.jpg",
      rating: 4.8,
      distanceKm: 1.4,
      etaMinutes: 4,
    );

Future<void> _pumpCard(WidgetTester tester, Driver? driver) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: DriverCard(driver: driver)),
      ),
    ),
  );
  // Let the (unreachable in tests) photo request fail into its errorBuilder.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets("renders every field from a sample driver", (tester) async {
    await _pumpCard(tester, _sampleDriver());

    expect(find.text("Dara Sok"), findsOneWidget);
    expect(find.text("4.8"), findsOneWidget); // rating chip value
    expect(find.text("Honda Dream · 1AB-2345"), findsOneWidget);
    expect(find.text("ETA 4 min"), findsOneWidget);
    expect(find.text("1.20 /km"), findsOneWidget);
  });

  testWidgets("empty optional fields fall back to placeholders without throwing",
      (tester) async {
    await _pumpCard(
      tester,
      const Driver(
        id: 2,
        userId: 0,
        carModel: "",
        plate: "",
        licenseNo: "",
        verified: false,
        online: false,
        pricePerKm: 0,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text("Driver"), findsOneWidget); // name placeholder
  });

  testWidgets("null driver renders placeholders without throwing",
      (tester) async {
    await _pumpCard(tester, null);

    expect(tester.takeException(), isNull);
    expect(find.text("Driver"), findsOneWidget);
  });

  testWidgets("invalid values (NaN rating, negative price/eta) fall back",
      (tester) async {
    await _pumpCard(
      tester,
      Driver(
        id: 3,
        userId: 0,
        carModel: " ",
        plate: "",
        licenseNo: "",
        verified: false,
        online: false,
        pricePerKm: -5,
        name: "   ",
        rating: double.nan,
        etaMinutes: -3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text("Driver"), findsOneWidget); // whitespace-only name
    expect(find.text("—"), findsNWidgets(3)); // rating · car · rate
    expect(find.text("ETA —"), findsOneWidget);
    expect(find.textContaining("/km"), findsNothing);
  });
}
