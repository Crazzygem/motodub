import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "package:latlong2/latlong.dart";

import "../../core/models/ride.dart";
import "../../core/theme/app_theme.dart";
import "../booking/booking_sheet.dart" show kOsmTileUrl;
import "tracking_provider.dart";

/// Live tracking (Task 5.1): flutter_map with pickup/dropoff pins, dashed
/// route and a heartbeat-driven driver marker; below it the 5-step status
/// stepper, driver info card once accepted, and cancel per §2 rules.
/// `completed` hands over to /rating/{rideId} (Task 7.1 rating screen).
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.rideId, this.tileLayer});

  final int rideId;

  /// Injectable tile layer — tests pass a stub so nothing touches network.
  final Widget? tileLayer;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  bool _handedOffToRating = false;

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider(widget.rideId));
    _handOffWhenCompleted(tracking);

    return Scaffold(
      body: SafeArea(
        child: switch (tracking) {
          TrackingState(loading: true, ride: null, error: null) =>
            const Center(child: CircularProgressIndicator()),
          TrackingState(error: final error?, ride: null) =>
            _ErrorPanel(message: error),
          _ => _Content(
              tracking: tracking,
              tileLayer: widget.tileLayer,
              onCancel: () =>
                  ref.read(trackingProvider(widget.rideId).notifier).cancel(),
              onRetry: () =>
                  ref.read(trackingProvider(widget.rideId).notifier).retry(),
            ),
        },
      ),
    );
  }

  /// One-way door to the rating flow — fires for rides that arrive
  /// completed AND ones that complete live (guard makes it idempotent).
  void _handOffWhenCompleted(TrackingState tracking) {
    if (_handedOffToRating || tracking.ride?.status != "completed") return;
    _handedOffToRating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push("/rating/${widget.rideId}");
    });
  }
}

// --- content ---------------------------------------------------------------------

class _Content extends StatelessWidget {
  const _Content({
    required this.tracking,
    required this.onCancel,
    required this.onRetry,
    this.tileLayer,
  });

  final TrackingState tracking;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final Widget? tileLayer;

  @override
  Widget build(BuildContext context) {
    final ride = tracking.ride!;
    final jakarta = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: _MapPanel(
              ride: ride,
              driverPosition: tracking.driverPosition,
              tileLayer: tileLayer,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusStepper(status: ride.status),
                const SizedBox(height: 14),
                _TripBlock(ride: ride),
                const SizedBox(height: 14),
                if (tracking.error != null) ...[
                  _ErrorBanner(message: tracking.error!),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: onRetry, child: const Text("Retry")),
                  ),
                  const SizedBox(height: 6),
                ],
                ...switch (ride.status) {
                  // Waiting — no card yet, but the customer stays in control.
                  "requested" => [
                      Text(
                        "Waiting for your driver to respond…",
                        textAlign: TextAlign.center,
                        style: jakarta.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      _CancelButton(canceling: tracking.canceling, onCancel: onCancel),
                    ],
                  "accepted" || "en_route" || "in_progress" => [
                      _DriverCard(ride: ride),
                      const SizedBox(height: 14),
                      _CancelButton(canceling: tracking.canceling, onCancel: onCancel),
                    ],
                  "completed" => [
                      Text("Completed 🎉", textAlign: TextAlign.center,
                          style: GoogleFonts.sora(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.bookGreen)),
                    ],
                  "declined" => [
                      const _TerminalNote(
                        message: "The driver passed on your request",
                      ),
                    ],
                  _ => [
                      const _TerminalNote(message: "Your ride was cancelled"),
                    ],
                },
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- map -------------------------------------------------------------------------

/// Same conventions as the booking-sheet panel (§7): light OSM tiles,
/// pickup pin book-green, dropoff pin amber, dashed amber route. The extra
/// occupant here is the LIVE driver marker fed by driver:location.
class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.ride,
    required this.driverPosition,
    this.tileLayer,
  });

  final Ride ride;
  final LatLng? driverPosition;
  final Widget? tileLayer;

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(ride.pickupLat, ride.pickupLng);
    final dropoff = LatLng(ride.dropoffLat, ride.dropoffLng);

    return FlutterMap(
      options: MapOptions(
        initialCenter: _midpoint(pickup, dropoff),
        initialZoom: 12,
      ),
      children: [
        tileLayer ??
            TileLayer(
              urlTemplate: kOsmTileUrl,
              userAgentPackageName: "kh.motodub.app",
            ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [pickup, dropoff],
              strokeWidth: 3,
              color: AppColors.amber,
              pattern: StrokePattern.dashed(segments: [6, 6]),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: pickup,
              width: 34,
              height: 34,
              child: const Icon(Icons.trip_origin_rounded,
                  key: Key("pickup-pin"), color: AppColors.bookGreen, size: 30,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 6)]),
            ),
            Marker(
              point: dropoff,
              width: 34,
              height: 34,
              child: const Icon(Icons.location_on_rounded,
                  key: Key("dropoff-pin"), color: AppColors.amber, size: 32,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 6)]),
            ),
            if (driverPosition != null)
              Marker(
                point: driverPosition!,
                width: 38,
                height: 38,
                child: Container(
                  key: const Key("driver-pin"),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.amber, width: 2.5),
                  ),
                  child: const Icon(Icons.local_taxi_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ],
    );
  }

  LatLng _midpoint(LatLng a, LatLng b) => LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );
}

// --- stepper ---------------------------------------------------------------------

/// requested → accepted → en_route → in_progress → completed, colored like
/// the driver-side stepper (DESIGN §5): done=green, active=amber, pending=line.
class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});

  final String status;

  static const _steps = <({String title, String status})>[
    (title: "Requested", status: "requested"),
    (title: "Accepted", status: "accepted"),
    (title: "En route", status: "en_route"),
    (title: "Riding", status: "in_progress"),
    (title: "Done", status: "completed"),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexWhere((s) => s.status == status);
    if (current < 0) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in _steps.indexed) ...[
          if (i > 0) const _StepLine(),
          Expanded(
            child: _StepDot(title: step.title, index: i, current: current),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.title, required this.index, required this.current});

  final String title;
  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final reached = index <= current;
    final isCurrent = index == current;

    final color = !reached
        ? AppColors.line
        : isCurrent
            ? AppColors.amber
            : AppColors.bookGreen;

    return Column(
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: reached ? AppColors.ink : AppColors.faint,
                ),
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 2,
      margin: const EdgeInsets.only(top: 6),
      color: AppColors.line,
    );
  }
}

// --- trip block ------------------------------------------------------------------

class _TripBlock extends StatelessWidget {
  const _TripBlock({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _addressRow(context, const Color(0xFF10B981), ride.pickupAddress),
        const SizedBox(height: 6),
        _addressRow(context, AppColors.amber, ride.dropoffAddress),
      ],
    );
  }

  Widget _addressRow(BuildContext context, Color dotColor, String address) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

// --- driver card -----------------------------------------------------------------

/// Car · plate · phone from the GET /api/rides/{id} driver snapshot —
/// appears once the ride is accepted (Task 5.1 step 3).
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final jakarta = Theme.of(context).textTheme;
    final carParts = [
      if ((ride.driverCarModel ?? "").trim().isNotEmpty)
        ride.driverCarModel!.trim(),
      if ((ride.driverPlate ?? "").trim().isNotEmpty) ride.driverPlate!.trim(),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surface,
            child: const Icon(Icons.local_taxi_rounded,
                color: AppColors.muted, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (ride.driverName?.trim().isEmpty ?? true)
                      ? "Your driver"
                      : ride.driverName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  carParts.isEmpty ? "—" : carParts.join(" · "),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if ((ride.driverPhone ?? "").isNotEmpty)
            Row(
              children: [
                const Icon(Icons.call_rounded,
                    size: 15, color: AppColors.amberDeep),
                const SizedBox(width: 4),
                Text(ride.driverPhone!, style: jakarta.labelMedium),
              ],
            ),
        ],
      ),
    );
  }
}

// --- buttons & notes -------------------------------------------------------------

/// Destructive action styled like the request-card Decline (white bg,
/// red text, red border — DESIGN §5); disabled while the call is in flight.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.canceling, required this.onCancel});

  final bool canceling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: canceling ? null : onCancel,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.passRed,
        disabledBackgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.passRed.withValues(alpha: .45),
        side: const BorderSide(color: AppColors.passRed),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: canceling
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text("Cancel ride"),
    );
  }
}

class _TerminalNote extends StatelessWidget {
  const _TerminalNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.line.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => context.go("/customer"),
          child: const Text("Back to deck"),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.passRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.passRed.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.passRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.passRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go("/customer"),
            child: const Text("Back to deck"),
          ),
        ],
      ),
    );
  }
}
