import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:duboun/core/models/driver.dart";
import "package:duboun/core/theme/app_theme.dart";
import "package:duboun/features/deck/deck_provider.dart";
import "package:duboun/features/deck/driver_card.dart";
import "package:duboun/features/deck/swipe_deck.dart";
import "package:duboun/features/shared/photo_viewer.dart";

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

Driver _driverWithGallery(List<String> photos) => Driver(
      id: 1,
      userId: 11,
      carModel: "Honda Dream",
      plate: "1AB-2345",
      licenseNo: "L-0001",
      verified: true,
      online: true,
      pricePerKm: 1.20,
      name: "Dara Sok",
      rating: 4.8,
      distanceKm: 1.4,
      etaMinutes: 4,
      vehiclePhotos: photos,
    );

/// Taps the hero photo in horizontal thirds — tinder pager contract:
/// -1 = left zone (previous), 0 = middle (viewer), 1 = right zone (next).
Future<void> _tapHeroZone(WidgetTester tester, int zone) async {
  final finder = find.byKey(const Key("driver-card-photo"));
  final width = tester.getSize(finder).width;
  await tester.tapAt(
    tester.getCenter(finder) + Offset(zone * width / 3, 0),
  );
}

Container _dot(WidgetTester tester, int index) =>
    tester.widget<Container>(find.byKey(Key("driver-card-dot-$index")));

/// Rendered pill width without the dot's symmetric margin (16 active / 6).
double _dotWidth(WidgetTester tester, int index) => tester.getSize(
      find.descendant(
        of: find.byKey(Key("driver-card-dot-$index")),
        matching: find.byType(DecoratedBox),
      ),
    ).width;

Color _dotColor(WidgetTester tester, int index) =>
    (_dot(tester, index).decoration! as BoxDecoration).color!;

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
    // The DUBOUN watermark stays readable above the photo.
    expect(find.text("DUBOUN"), findsOneWidget);
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

  testWidgets("tapping the hero photo opens the fullscreen viewer",
      (tester) async {
    await _pumpCardOnce(tester, _driverWithVehiclePhoto("/uploads/bike.png"));

    await tester.tap(find.byKey(const Key("driver-card-photo")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PhotoViewer), findsOneWidget);
    // Watermark stays card chrome — the viewer shows the raw photo.
    expect(find.text("DUBOUN"), findsOneWidget);
  });

  testWidgets("a card without a vehicle photo has no photo tap target",
      (tester) async {
    await _pumpCardOnce(tester, _driverWithVehiclePhoto(null));

    expect(find.byKey(const Key("driver-card-photo")), findsNothing);
    await tester.tap(find.byIcon(Icons.local_taxi_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets("a broken vehicle_photo URL has no photo tap target either",
      (tester) async {
    await _pumpCard(tester, _driverWithVehiclePhoto("not-a-url"));

    expect(find.byKey(const Key("driver-card-photo")), findsNothing);
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets("side tap zones page a multi-photo hero and move the active dot",
      (tester) async {
    await _pumpCardOnce(
      tester,
      _driverWithGallery(
        ["/uploads/one.png", "/uploads/two.png", "/uploads/three.png"],
      ),
    );

    expect(_heroImage(tester)!.url, endsWith("one.png"));
    expect(find.byKey(const Key("driver-card-dots")), findsOneWidget);
    expect(_dotColor(tester, 0), AppColors.amber); // photo 1 starts active
    expect(_dotWidth(tester, 0), 16); // active dot is the wider one
    expect(_dotWidth(tester, 1), 6);
    expect(_dotColor(tester, 1), isNot(AppColors.amber));

    await _tapHeroZone(tester, 1); // right third -> next photo
    await tester.pump(); // start the crossfade
    await tester.pump(const Duration(milliseconds: 300)); // settle + drop old

    expect(_heroImage(tester)!.url, endsWith("two.png"));
    expect(_dotColor(tester, 1), AppColors.amber); // active dot followed
    expect(_dotWidth(tester, 1), 16);
    expect(_dotColor(tester, 0), isNot(AppColors.amber));

    await _tapHeroZone(tester, -1); // left third -> previous photo
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_heroImage(tester)!.url, endsWith("one.png"));
  });

  testWidgets("single-photo heroes: side taps do nothing, middle opens viewer",
      (tester) async {
    await _pumpCardOnce(tester, _driverWithVehiclePhoto("/uploads/solo.png"));

    expect(find.byKey(const Key("driver-card-dots")), findsNothing);

    await _tapHeroZone(tester, 1); // right zone
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewer), findsNothing); // next is a no-op
    expect(_heroImage(tester)!.url, endsWith("solo.png"));

    await _tapHeroZone(tester, -1); // left zone
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewer), findsNothing); // prev is a no-op
    expect(_heroImage(tester)!.url, endsWith("solo.png"));

    await _tapHeroZone(tester, 0); // middle zone
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewer), findsOneWidget);
  });

  testWidgets("middle tap on a paged hero opens the viewer at the CURRENT photo",
      (tester) async {
    await _pumpCardOnce(
      tester,
      _driverWithGallery(["/uploads/one.png", "/uploads/two.png"]),
    );

    await _tapHeroZone(tester, 1); // page to photo 2 first
    await tester.pump(const Duration(milliseconds: 300));
    await _tapHeroZone(tester, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<PhotoViewer>(find.byType(PhotoViewer)).url,
      "http://10.0.2.2:3000/uploads/two.png",
    );
  });

  testWidgets("deck swipe still books after opening and dismissing the viewer",
      (tester) async {
    Driver? booked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deckProvider.overrideWith(() => _FakeDeck([
                _driverWithVehiclePhoto("/uploads/bike.png"),
              ])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SwipeDeck(onSwipedRight: (d) => booked = d),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("driver-card-photo")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key("photo-viewer-close")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewer), findsNothing);

    // The fling STARTS on the photo — the tap detector must not swallow it.
    await tester.fling(
      find.byKey(const Key("driver-card-photo")),
      const Offset(500, 0),
      3000,
    );
    await tester.pumpAndSettle();

    expect(booked?.id, 1);
  });

  testWidgets("a deck fling starting on a multi-photo hero still pops the card",
      (tester) async {
    Driver? booked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deckProvider.overrideWith(() => _FakeDeck([
                _driverWithGallery(["/uploads/one.png", "/uploads/two.png"]),
              ])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SwipeDeck(onSwipedRight: (d) => booked = d),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The fling STARTS on the paged hero — the pager must not swallow it.
    await tester.fling(
      find.byKey(const Key("driver-card-photo")),
      const Offset(500, 0),
      3000,
    );
    await tester.pumpAndSettle();

    expect(booked?.id, 1);
  });
}

/// Bypasses HTTP for the deck-regression harness (same shape as
/// swipe_deck_test's fake).
class _FakeDeck extends DeckNotifier {
  _FakeDeck(this.cards);

  final List<Driver> cards;

  @override
  Future<DeckState> build() async =>
      DeckState(cards: List.of(cards), swipedLeft: const <int>{});
}
