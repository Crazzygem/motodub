import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/models/ride.dart";
import "package:motodub/features/driver/request_card.dart";
import "package:motodub/features/driver/ride_controls.dart";

const _request = Ride(
  id: 100,
  customerId: 9,
  driverId: 4,
  status: "requested",
  pickupLat: 11.5564,
  pickupLng: 104.9282,
  pickupAddress: "Central Market",
  dropoffLat: 11.5449,
  dropoffLng: 104.8922,
  dropoffAddress: "Airport",
  customerName: "Srey",
  customerAvgRating: 4.5,
);

Ride _withStatus(String status) => Ride(
      id: 100,
      customerId: 9,
      driverId: 4,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  group("RequestCard", () {
    testWidgets("renders customer name/rating and both addresses", (
      tester,
    ) async {
      await _pump(
        tester,
        RequestCard(request: _request, onAccept: () {}, onDecline: () {}),
      );

      expect(find.text("Srey"), findsOneWidget);
      expect(find.text("4.5"), findsOneWidget);
      expect(find.text("Central Market"), findsOneWidget);
      expect(find.text("Airport"), findsOneWidget);
    });

    testWidgets("shows the trip distance from the ride coordinates", (
      tester,
    ) async {
      await _pump(
        tester,
        RequestCard(request: _request, onAccept: () {}, onDecline: () {}),
      );

      // Central Market → Airport straight line ≈ 4.1 km.
      expect(haversineKm(11.5564, 104.9282, 11.5449, 104.8922),
          closeTo(4.13, 0.05));
      expect(find.text("4.1 km"), findsOneWidget);
    });

    testWidgets("Accept dispatches onAccept", (tester) async {
      var accepted = false;
      var declined = false;
      await _pump(
        tester,
        RequestCard(
          request: _request,
          onAccept: () => accepted = true,
          onDecline: () => declined = true,
        ),
      );

      await tester.tap(find.text("Accept"));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
      expect(declined, isFalse);
    });

    testWidgets("Decline dispatches onDecline", (tester) async {
      var accepted = false;
      var declined = false;
      await _pump(
        tester,
        RequestCard(
          request: _request,
          onAccept: () => accepted = true,
          onDecline: () => declined = true,
        ),
      );

      await tester.tap(find.text("Decline"));
      await tester.pumpAndSettle();

      expect(declined, isTrue);
      expect(accepted, isFalse);
    });
  });

  group("RideControls", () {
    testWidgets("accepted shows 'On my way' and dispatches onStart", (
      tester,
    ) async {
      var started = false;
      await _pump(
        tester,
        RideControls(
          ride: _withStatus("accepted"),
          onStart: () => started = true,
        ),
      );

      final cta = find.widgetWithText(FilledButton, "On my way");
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });

    testWidgets("en_route shows 'Start ride' and dispatches onStartRide", (
      tester,
    ) async {
      var startedRide = false;
      await _pump(
        tester,
        RideControls(
          ride: _withStatus("en_route"),
          onStartRide: () => startedRide = true,
        ),
      );

      final cta = find.widgetWithText(FilledButton, "Start ride");
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(startedRide, isTrue);
    });

    testWidgets("in_progress shows 'End ride' and dispatches onComplete", (
      tester,
    ) async {
      var completed = false;
      await _pump(
        tester,
        RideControls(
          ride: _withStatus("in_progress"),
          onComplete: () => completed = true,
        ),
      );

      final cta = find.widgetWithText(FilledButton, "End ride ✓");
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets("completed renders the done state with no action button", (
      tester,
    ) async {
      await _pump(tester, RideControls(ride: _withStatus("completed")));

      expect(find.textContaining("Completed"), findsOneWidget);
      // The only button left is the disabled green "done" pill — nothing
      // can advance a completed ride.
      final buttons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      ).toList();
      expect(buttons, hasLength(1));
      expect(buttons.single.onPressed, isNull);
    });
  });
}
