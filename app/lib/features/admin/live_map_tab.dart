import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:latlong2/latlong.dart";

import "../../core/api/admin_repo.dart";
import "../../core/l10n/l10n.dart";
import "../../core/theme/app_theme.dart";
import "../booking/booking_sheet.dart" show kOsmTileUrl;
import "admin_screen.dart" show adminRepoProvider;

/// Phnom Penh — every seeded driver and demo ride lives around this center.
const _phnomPenhCenter = LatLng(11.5564, 104.9282);

/// Task 6.3 (stretch) — live map of online drivers. Admin sockets never
/// receive driver:location (it fans out to location:{driverId} rooms only),
/// so per spec this polls GET /api/admin/drivers every 10s instead. Pins:
/// verified + online + a reported heartbeat position; tap for identity.
class LiveMapTab extends ConsumerStatefulWidget {
  const LiveMapTab({super.key, this.tileLayer});

  /// Injectable tile layer — tests pass a stub so nothing touches network.
  final Widget? tileLayer;

  @override
  ConsumerState<LiveMapTab> createState() => _LiveMapTabState();
}

class _LiveMapTabState extends ConsumerState<LiveMapTab> {
  static const _pollInterval = Duration(seconds: 10);

  Timer? _poll;
  bool _disposed = false;

  /// Null until the first successful load — that IS the loading state.
  List<AdminDriver>? _drivers;
  String? _error;
  AdminDriver? _selected;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await ref.read(adminRepoProvider).drivers();
    if (_disposed) return;

    if (result.isOk) {
      setState(() {
        _drivers = result.data;
        _error = null;
        if (_selected != null && !_pinnable(result.data!).contains(_selected)) {
          _selected = null;
        }
      });
      return;
    }
    // First load failing is user-facing; a failed refresh keeps last good
    // pins and retries silently on the next tick.
    if (_drivers == null) setState(() => _error = result.message);
  }

  List<AdminDriver> _pinnable(List<AdminDriver> rows) => rows
      .where((d) =>
          d.online && d.verified && d.lat != null && d.lng != null)
      .toList();

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final drivers = _drivers;

    if (error != null) return _ErrorPanel(message: error, onRetry: _refresh);
    if (drivers == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    final pins = _pinnable(drivers);
    final selected = _selected;

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: _phnomPenhCenter,
            initialZoom: 12,
          ),
          children: [
            widget.tileLayer ??
                TileLayer(
                  urlTemplate: kOsmTileUrl,
                  userAgentPackageName: "kh.duboun.app",
                ),
            MarkerLayer(
              markers: [
                for (final driver in pins)
                  Marker(
                    point: LatLng(driver.lat!, driver.lng!),
                    width: 38,
                    height: 38,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = driver),
                      child: Container(
                        key: Key("map-pin-${driver.driverId}"),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.amber, width: 2.5),
                        ),
                        child: const Icon(Icons.local_taxi_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (pins.isEmpty)
          Center(
            child: IgnorePointer(
              child: _OverlayPill(
                key: const Key("live-map-empty"),
                label: context.l10n.liveMapEmpty,
              ),
            ),
          ),
        if (selected != null)
          _PinCard(
            driver: selected,
            onClose: () => setState(() => _selected = null),
          ),
      ],
    );
  }
}

// --- overlays --------------------------------------------------------------------

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokensOf(context).card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokensOf(context).line),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: tokensOf(context).textSecondary),
      ),
    );
  }
}

/// Tap tooltip for one pin — name, car · plate, rating (tracking-screen
/// driver-card language, floating over the map's bottom edge).
class _PinCard extends StatelessWidget {
  const _PinCard({required this.driver, required this.onClose});

  final AdminDriver driver;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carParts = [
      if ((driver.carModel ?? "").trim().isNotEmpty)
        driver.carModel!.trim(),
      if ((driver.plate ?? "").trim().isNotEmpty) driver.plate!.trim(),
    ];

    final tokens = tokensOf(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.line),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.ink,
              child: const Icon(Icons.local_taxi_rounded,
                  color: AppColors.amber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    carParts.isEmpty ? "—" : carParts.join(" · "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text("★ ${driver.rating.toStringAsFixed(1)}",
                style: theme.textTheme.labelMedium),
            IconButton(
              key: const Key("pin-card-close"),
              icon: Icon(Icons.close_rounded,
                  size: 20, color: tokens.textSecondary),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10nOf(context).couldntLoadDrivers,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10nOf(context).tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
