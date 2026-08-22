import "dart:math" as math;

import "package:flutter/material.dart";

import "../../core/models/ride.dart";
import "../../core/theme/app_theme.dart";

/// Great-circle distance in km (client-side twin of the server's
/// `utils/distance.js`, fed straight from the ride payload coords).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double deg) => deg * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

/// The incoming ride: who wants to go where, how far, and the two verdict
/// buttons. DESIGN.md §5 — avatar + name/rating, trip-km pill, green-dot
/// pickup rail → ink-dot dropoff, Accept/Decline 50/50.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final Ride request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = request.customerName ?? "Customer";
    final initials = name
        .split(" ")
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join();
    final rating = request.customerAvgRating?.toStringAsFixed(1);
    final km = haversineKm(
      request.pickupLat,
      request.pickupLng,
      request.dropoffLat,
      request.dropoffLng,
    ).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E111827),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.amber,
                child: Text(
                  initials.isEmpty ? "?" : initials,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.amberDeep),
                          const SizedBox(width: 3),
                          Text(rating, style: theme.textTheme.labelMedium),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$km km",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LegRow(dotColor: AppColors.bookGreen, address: request.pickupAddress),
          const SizedBox(height: 8),
          _LegRow(dotColor: AppColors.ink, address: request.dropoffAddress),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bookGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onAccept,
                  child: const Text("Accept"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.passRed,
                    side: const BorderSide(color: AppColors.passRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onDecline,
                  child: const Text("Decline"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.dotColor, required this.address});

  final Color dotColor;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 4.5, backgroundColor: dotColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
