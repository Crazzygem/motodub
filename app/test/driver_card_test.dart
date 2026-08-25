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

Driver _driverWithVehiclePhoto(String? vehiclePhoto) => Driver(
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
      vehiclePhoto: vehiclePhoto,
    );

/// Builds the card and flushes ONE frame — enough for the widget tree to
/// exist, but not long enough for the (unreachable in tests) photo requests
/// to fail into their errorBuilders. Image-presence assertions stay
/// deterministic this way.
Future<void> _pumpCardOnce(WidgetTester tester, Driver? driver) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: DriverCard(driver: driver)),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpCard(WidgetTester tester, Driver? driver) async {
  await _pumpCardOnce(tester, driver);
  // Let the (unreachable in tests) photo request fail into its errorBuilder.
  await tester.pump(const Duration(milliseconds: 300));
}

NetworkImage? _heroImage(WidgetTester tester) {
  final images = tester.widgetList<Image>(
    find.descendant(of: find.byType(DriverCard), matching: find.byType(Image)),
  );
  for (final image in images) {
    final provider = image.image;
    if (provider is NetworkImage && provider.url.contains("/uploads/")) {
      return provider;
    }
  }
  return null;
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

  testWidgets("a vehicle_photo URL becomes the card hero image",
      (tester) async {
    await _pumpCardOnce(
      tester,
      _driverWithVehiclePhoto("http://10.0.2.2:3000/uploads/bike.png"),
    );

    final hero = _heroImage(tester);
    expect(hero, isNotNull);
    expect(hero!.url, "http://10.0.2.2:3000/uploads/bike.png");
    // The MOTODUB watermark stays readable above the photo.
    expect(find.text("MOTODUB"), findsOneWidget);
  });

  testWidgets("a relative vehicle_photo resolves against the API base URL",
      (tester) async {
    await _pumpCardOnce(
      tester,
      _driverWithVehiclePhoto("/uploads/relative.webp"),
    );

    final hero = _heroImage(tester);
    expect(hero, isNotNull);
    expect(hero!.url, "http://10.0.2.2:3000/uploads/relative.webp");
  });

  testWidgets("no vehicle_photo keeps the taxi-icon fallback as the hero",
      (tester) async {
    await _pumpCard(tester, _driverWithVehiclePhoto(null));

    expect(_heroImage(tester), isNull);
    expect(find.byIcon(Icons.local_taxi_rounded), findsOneWidget);
  });

  testWidgets("a broken vehicle_photo URL silently falls back to the icon",
      (tester) async {
    await _pumpCard(
      tester,
      _driverWithVehiclePhoto("not-a-url"),
    );

    expect(tester.takeException(), isNull);
    expect(_heroImage(tester), isNull);
    expect(find.byIcon(Icons.local_taxi_rounded), findsOneWidget);
  });

  testWidgets("the driver avatar circle shows the driver photo when set",
      (tester) async {
    await _pumpCardOnce(tester, _sampleDriver());

    expect(find.byKey(const Key("driver-card-avatar")), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is NetworkImage &&
            (w.image as NetworkImage).url == "https://example.com/dara.jpg",
      ),
      findsOneWidget,
    );
  });

  testWidgets("the avatar circle falls back to name initials", (tester) async {
    await _pumpCard(
      tester,
      const Driver(
        id: 5,
        userId: 0,
        carModel: "Honda Dream",
        plate: "1AB-2345",
        licenseNo: "L-0001",
        verified: true,
        online: true,
        pricePerKm: 1.20,
        name: "Dara Sok",
        rating: 4.8,
      ),
    );

    expect(find.byKey(const Key("driver-card-avatar")), findsOneWidget);
    expect(find.text("DS"), findsOneWidget); // initials fallback
  });
}
