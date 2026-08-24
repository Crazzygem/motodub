import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/api_client.dart";
import "../../core/models/ride.dart";
import "../booking/booking_provider.dart" show rideRepoProvider;

/// Read-only rollup of a driver's own rides (`GET /api/rides/mine`) for the
/// home-screen earnings summary + recent-activity list. Pure derivation —
/// the driver_provider state machine stays untouched.
class DriverSummary {
  const DriverSummary({
    required this.completedToday,
    this.avgRating,
    required this.recent,
  });

  /// Rides finished today (local calendar day).
  final int completedToday;

  /// Average rating the driver received (`customer_rating`), 1 decimal;
  /// null before anyone has rated them.
  final double? avgRating;

  /// Up to 5 most recent rides, newest first (server order + id tie-break).
  final List<Ride> recent;

  factory DriverSummary.fromRides(List<Ride> rides, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);

    var completedToday = 0;
    final rated = <int>[];
    for (final ride in rides) {
      if (ride.status == "completed") {
        final created = ride.createdAt?.toLocal();
        if (created != null &&
            created.year == today.year &&
            created.month == today.month &&
            created.day == today.day) {
          completedToday++;
        }
      }
      final rating = ride.customerRating;
      if (rating != null) rated.add(rating);
    }

    final avg = rated.isEmpty
        ? null
        : (rated.reduce((a, b) => a + b) / rated.length * 10).round() / 10;

    final sorted = [...rides]..sort((a, b) {
        final byDate = _compare(b.createdAt, a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    return DriverSummary(
      completedToday: completedToday,
      avgRating: avg,
      recent: sorted.take(5).toList(),
    );
  }

  static int _compare(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}

/// Compact relative timestamp for the activity rows — "just now", "5m ago",
/// "2h ago", or a date ("14 Aug"). [now] is injectable for tests.
String relativeTimeLabel(DateTime? utc, {DateTime? now}) {
  if (utc == null) return "";
  final reference = (now ?? DateTime.now()).toLocal();
  final time = utc.toLocal();
  final diff = reference.difference(time);

  if (diff.inMinutes < 1) return "just now";
  if (diff.inHours < 1) return "${diff.inMinutes}m ago";
  if (diff.inDays < 1) return "${diff.inHours}h ago";

  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  if (time.year == reference.year) {
    return "${time.day} ${months[time.month - 1]}";
  }
  return "${time.day} ${months[time.month - 1]} ${time.year}";
}

/// One fetch of the driver's own rides; feeds both the earnings summary
/// and the activity list. Errors surface as the widget's §9 error state.
final driverSummaryProvider = FutureProvider.autoDispose<DriverSummary>(
  (ref) async {
    final result = await ref.watch(rideRepoProvider).mine();
    if (!result.isOk) {
      throw ApiException(
        result.code ?? "INTERNAL",
        result.message ?? "Couldn't load your activity.",
      );
    }
    return DriverSummary.fromRides(result.data ?? const <Ride>[]);
  },
);
