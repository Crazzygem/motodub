import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_map/flutter_map.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "package:latlong2/latlong.dart";

import "../../core/api/error_messages.dart" show localizedErrorFor;
import "../../core/l10n/l10n.dart";
import "../../core/models/driver.dart";
import "../../core/theme/app_theme.dart";
import "../shared/driver_photo_avatar.dart";
import "booking_provider.dart";

/// OpenStreetMap raster tiles — no API key (locked decision 9).
const String kOsmTileUrl =
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png";

/// Booking confirm sheet (Task 3.5): driver mini-header, map with
/// pickup/dropoff pins + dashed link, free-text addresses, cash-only confirm.
/// On success the server answers with a `requested` ride and we push
/// /tracking/{rideId}; on failure an in-sheet banner shows mapped copy.
Future<void> showBookingSheet(
  BuildContext context,
  Driver driver, {
  Widget? tileLayer,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: tokensOf(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: BookingSheet(driver: driver, tileLayer: tileLayer),
    ),
  );
}

class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.driver, this.tileLayer});

  final Driver driver;

  /// Injectable tile layer — tests pass a stub so nothing touches network.
  final Widget? tileLayer;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pickupAddress = TextEditingController();
  late final TextEditingController _dropoffAddress = TextEditingController();

  @override
  void dispose() {
    _pickupAddress.dispose();
    _dropoffAddress.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    final form = ref.read(bookingProvider);
    final booking = ref.read(bookingProvider.notifier);
    booking.beginSubmit();

    final result = await ref.read(rideRepoProvider).create(
          driverId: widget.driver.id,
          pickupLat: form.pickup.latitude,
          pickupLng: form.pickup.longitude,
          pickupAddress: _pickupAddress.text.trim(),
          dropoffLat: form.dropoff.latitude,
          dropoffLng: form.dropoff.longitude,
          dropoffAddress: _dropoffAddress.text.trim(),
        );

    if (!mounted) return;
    if (!result.isOk) {
      booking.endSubmit(
        error: localizedErrorFor(
          l10nOf(context),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    Navigator.of(context).pop(); // close the sheet…
    context.push("/tracking/${result.data!.id}"); // …then track the ride
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(bookingProvider);
    final l10n = context.l10n;
    final jakarta = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(context),
                const SizedBox(height: 8),
                _MiniHeader(driver: widget.driver),
                const SizedBox(height: 14),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _MapPanel(tileLayer: widget.tileLayer),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ActivePin>(
                  segments: [
                    ButtonSegment(
                      value: ActivePin.pickup,
                      icon: const Icon(Icons.trip_origin_rounded, size: 16),
                      label: Text(l10n.pickupLabel),
                    ),
                    ButtonSegment(
                      value: ActivePin.dropoff,
                      icon: const Icon(Icons.location_on_rounded, size: 16),
                      label: Text(l10n.dropoffLabel),
                    ),
                  ],
                  selected: {form.activePin},
                  onSelectionChanged: (selection) => ref
                      .read(bookingProvider.notifier)
                      .setActivePin(selection.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pickupAddress,
                  decoration: InputDecoration(
                    labelText: l10n.pickupAddressLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        const Icon(Icons.trip_origin_rounded, size: 18),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? l10n.enterPickupAddress
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dropoffAddress,
                  decoration: InputDecoration(
                    labelText: l10n.dropoffAddressLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        const Icon(Icons.location_on_rounded, size: 18),
                  ),
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? l10n.enterDropoffAddress
                          : null,
                ),
                if (form.error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: form.error!),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: form.submitting ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bookGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: form.submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.confirmBooking),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.payCashNote,
                  textAlign: TextAlign.center,
                  style: jakarta.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dragHandle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.tokens.line,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}

// --- mini-header ---------------------------------------------------------------

/// Compact version of the swipe card identity: avatar, name+rating, car line,
/// asking-rate pill (§5 — display only, never a fare).
class _MiniHeader extends StatelessWidget {
  const _MiniHeader({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final jakarta = Theme.of(context).textTheme;
    final tokens = tokensOf(context);
    final carParts = [
      if (driver.carModel.trim().isNotEmpty) driver.carModel.trim(),
      if (driver.plate.trim().isNotEmpty) driver.plate.trim(),
    ];

    return Row(
      children: [
        // Shared identity circle: vehicle photo → avatar → taxi icon.
        DriverPhotoAvatar(
          vehiclePhoto: driver.vehiclePhoto,
          photo: driver.photo,
          backgroundColor: tokens.inset,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      (driver.name?.trim().isEmpty ?? true)
                          ? l10n.driverFallback
                          : driver.name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.star_rounded,
                      size: 15, color: Color(0xFFFCD34D)),
                  const SizedBox(width: 2),
                  Text(
                    _ratingText(driver.rating),
                    style: jakarta.labelMedium,
                  ),
                ],
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.amber,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            "${driver.pricePerKm.toStringAsFixed(2)} /km",
            style: jakarta.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink, // amber always carries ink
            ),
          ),
        ),
      ],
    );
  }

  String _ratingText(double? rating) =>
      (rating == null || !rating.isFinite || rating < 0 || rating > 5)
          ? "—"
          : rating.toStringAsFixed(1);
}

// --- map ------------------------------------------------------------------------

/// Tap to move the active pin; pins themselves drag too. A dashed polyline
/// links pickup → dropoff (§3.5 — no routing API).
class _MapPanel extends ConsumerWidget {
  const _MapPanel({this.tileLayer});

  final Widget? tileLayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);

    return SizedBox(
      height: 240,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _midpoint(form.pickup, form.dropoff),
          initialZoom: 11.5,
          onTap: (_, latLng) => notifier.moveActivePin(latLng),
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
                points: [form.pickup, form.dropoff],
                strokeWidth: 3,
                color: AppColors.amber,
                // non-const: dashed() carries default segments
                pattern: StrokePattern.dashed(segments: [6, 6]),
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              // flutter_map Markers are data objects; the child widget lives
              // under the map tree so its context can reach MapCamera.
              Marker(
                point: form.pickup,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: _DraggablePin(
                  point: form.pickup,
                  color: AppColors.bookGreen,
                  icon: Icons.trip_origin_rounded,
                  onMoved: (point) =>
                      notifier.movePin(ActivePin.pickup, point),
                ),
              ),
              Marker(
                point: form.dropoff,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: _DraggablePin(
                  point: form.dropoff,
                  color: AppColors.amber, // §7 pins: dropoff = amber
                  icon: Icons.location_on_rounded,
                  onMoved: (point) =>
                      notifier.movePin(ActivePin.dropoff, point),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LatLng _midpoint(LatLng a, LatLng b) => LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );
}

/// Pin glyph that pans itself via the current camera — no extra packages.
class _DraggablePin extends StatelessWidget {
  const _DraggablePin({
    required this.point,
    required this.color,
    required this.icon,
    required this.onMoved,
  });

  final LatLng point;
  final Color color;
  final IconData icon;
  final ValueChanged<LatLng> onMoved;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final camera = MapCamera.maybeOf(context);
        if (camera == null) return;
        onMoved(camera.screenOffsetToLatLng(
          camera.latLngToScreenOffset(point) + details.delta,
        ));
      },
      child: Icon(icon, color: color, size: 34, shadows: const [
        Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
      ]),
    );
  }
}

// --- error banner -----------------------------------------------------------------

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
