import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:duboun/core/api/api_client.dart";
import "package:duboun/core/api/error_messages.dart";
import "package:duboun/core/api/ride_repo.dart";
import "package:duboun/core/models/ride.dart";
import "package:duboun/core/theme/app_theme.dart";
import "package:duboun/features/booking/booking_provider.dart"
    show rideRepoProvider;
import "package:duboun/features/rides/history_screen.dart";

// Task 5.2 — history screen: status-colored badges, pull-to-refresh,
// empty state, error + retry. Repos subclass the real one over a dead
// Dio client (tracking_test / driver_home_test convention).
Ride _ride({
  required int id,
  required String status,
  String? driverName,
  String? customerName,
}) =>
    Ride(
      id: id,
      customerId: 9,
      driverId: 40,
      status: status,
      pickupLat: 11.5564,
      pickupLng: 104.9282,
      pickupAddress: "Central Market",
      dropoffLat: 11.5449,
      dropoffLng: 104.8922,
      dropoffAddress: "Airport",
      createdAt: DateTime(2026, 8, 21, 14, 30),
      updatedAt: DateTime(2026, 8, 21, 15, 10),
      customerName: customerName,
      customerAvgRating: customerName == null ? null : 4.5,
      driverName: driverName,
      driverCarModel: driverName == null ? null : "Toyota Highlander SUV",
      driverPlate: driverName == null ? null : "PP-1A-2345",
    );

ApiClient _deadClient() => ApiClient(dio: Dio());

/// Serves canned mine() results and records every fetch.
class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(_deadClient());

  ApiResult<List<Ride>> nextResult = ApiResult.ok(const <Ride>[]);

  int calls = 0;

  @override
  Future<ApiResult<List<Ride>>> mine() async {
    calls++;
    return nextResult;
  }
}

Future<void> _pump(WidgetTester tester, _StubRideRepo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rideRepoProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: HistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Color _badgeLabelColor(WidgetTester tester, int rideId) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(Key("history-badge-$rideId")),
      matching: find.byType(Text),
    ),
  );
  return text.style!.color!;
}

void main() {
  testWidgets("renders rides with correct status labels and colors",
      (tester) async {
    final repo = _StubRideRepo();
    repo.nextResult = ApiResult.ok([
      _ride(id: 1, status: "completed", driverName: "Dara"),
      _ride(id: 2, status: "cancelled", driverName: "Sophea"),
      _ride(id: 3, status: "declined", customerName: "Srey"),
    ]);
    await _pump(tester, repo);

    // Status labels…
    expect(find.text("Completed"), findsOneWidget);
    expect(find.text("Cancelled"), findsOneWidget);
    expect(find.text("Declined"), findsOneWidget);

    // …on DESIGN-token colored pills (completed green · cancelled grey ·
    // declined muted per §10.4).
    expect(_badgeLabelColor(tester, 1), AppColors.bookGreen);
    expect(_badgeLabelColor(tester, 2), AppColors.muted);
    expect(_badgeLabelColor(tester, 3), AppColors.muted);

    // Opposite-party names render.
    expect(find.textContaining("Dara"), findsWidgets);
    expect(find.textContaining("Srey"), findsOneWidget);

    // Route line + date.
    expect(find.textContaining("Central Market"), findsWidgets);
    expect(find.textContaining("Airport"), findsWidgets);
  });

  testWidgets("pull-to-refresh refetches the history", (tester) async {
    final repo = _StubRideRepo();
    repo.nextResult = ApiResult.ok([
      _ride(id: 1, status: "completed", driverName: "Dara"),
    ]);
    await _pump(tester, repo);
    expect(repo.calls, 1);

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
  });

  testWidgets("shows the empty state when there are no rides",
      (tester) async {
    final repo = _StubRideRepo();
    repo.nextResult = ApiResult.ok(const <Ride>[]);
    await _pump(tester, repo);

    expect(find.text("No rides yet"), findsOneWidget);
    expect(find.textContaining("trips"), findsOneWidget);
  });

  testWidgets("shows an error with working retry", (tester) async {
    final repo = _StubRideRepo();
    repo.nextResult = ApiResult.err(
      "NETWORK",
      errorMessageFor("NETWORK"),
    );
    await _pump(tester, repo);

    expect(find.text(networkUnreachableMessage), findsOneWidget);
    expect(repo.calls, 1);

    repo.nextResult = ApiResult.ok([
      _ride(id: 7, status: "completed", driverName: "Dara"),
    ]);
    await tester.tap(find.text("Try again"));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text("Completed"), findsOneWidget);
  });
}
