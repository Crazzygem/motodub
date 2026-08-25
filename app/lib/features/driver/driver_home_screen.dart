import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/api/api_client.dart";
import "../../core/api/ride_repo.dart";
import "../../core/models/driver.dart";
import "../../core/l10n/l10n.dart";
import "../../core/models/ride.dart";
import "../../core/theme/app_theme.dart";
import "../account/account_screen.dart";
import "../rides/history_screen.dart"
    show HistoryScreen, historyStatusColor, localizedStatusLabel;
import "driver_provider.dart";
import "driver_summary.dart";
import "request_card.dart";
import "ride_controls.dart";

/// The driver's working shell (Task 4.6, restructured to bottom nav):
/// Home (presence + vehicle + requests + summary), History and Account
/// behind a Material 3 [NavigationBar].
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Conditional swap — only the active tab is mounted.
      body: switch (_tab) {
        1 => const HistoryScreen(),
        2 => const AccountScreen(),
        _ => const _DriverHomeBody(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_rounded),
            label: context.l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: context.l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_rounded),
            label: context.l10n.navAccount,
          ),
        ],
      ),
    );
  }
}

class _DriverHomeBody extends ConsumerWidget {
  const _DriverHomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(driverProvider);

    // Task 7.1 — when an active ride turns `completed` (complete tap or
    // socket reconcile), hand off to the rating screen exactly once.
    ref.listen(driverProvider, (previous, next) {
      final completed = next.valueOrNull?.lastCompletedRideId;
      if (completed == null ||
          completed == previous?.valueOrNull?.lastCompletedRideId) {
        return;
      }
      context.push("/rating/$completed");
    });

    return SafeArea(
      child: home.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        error: (error, _) => _BootError(
          message: _messageFor(error, context.l10n),
          onRetry: () => ref.read(driverProvider.notifier).refresh(),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverSummaryProvider);
            ref.read(driverProvider.notifier).refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(context.l10n.motoDubDriverTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (state.vehicle != null) ...[
                _StatusCard(state: state),
                const SizedBox(height: 14),
              ],
              if (state.error != null) ...[
                _ErrorBanner(message: state.error!),
                const SizedBox(height: 14),
              ],
              if (state.incoming != null) ...[
                const SizedBox(height: 14),
                RequestCard(
                  request: state.incoming!,
                  onAccept: () =>
                      ref.read(driverProvider.notifier).accept(),
                  onDecline: () =>
                      ref.read(driverProvider.notifier).decline(),
                ),
              ],
              if (state.active != null) ...[
                const SizedBox(height: 14),
                RideControls(
                  ride: state.active!,
                  onStart: () => ref
                      .read(driverProvider.notifier)
                      .advance(RideAction.start),
                  onStartRide: () => ref
                      .read(driverProvider.notifier)
                      .advance(RideAction.startRide),
                  onComplete: () => ref
                      .read(driverProvider.notifier)
                      .advance(RideAction.complete),
                ),
              ],
              state.vehicle == null
                  ? _VehicleSetupForm(submit: (fields) => ref
                      .read(driverProvider.notifier)
                      .submitVehicle(
                        carModel: fields.carModel,
                        plate: fields.plate,
                        licenseNo: fields.licenseNo,
                        pricePerKm: fields.pricePerKm,
                      ))
                  : _VehicleCard(vehicle: state.vehicle!),
              const SizedBox(height: 14),
              const _EarningsAndActivity(),
            ],
          ),
        ),
      ),
    );
  }
}

String _messageFor(Object error, AppLocalizations s) {
  if (error is ApiException) return error.message;
  return s.errNetwork;
}

/// Presence card — grey dot offline → green online; the switch is hidden
/// entirely until a vehicle profile exists (the server rejects toggles
/// without one anyway).
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.state});

  final DriverHomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final s = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.tokens.line),
      ),
      child: Row(
        children: [
          _PresenceDot(online: state.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.online ? s.youAreOnline : s.youAreOffline,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  state.online ? s.receivingRequests : s.goOnlineHint,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: state.online,
            onChanged: (value) =>
                ref.read(driverProvider.notifier).toggleOnline(value),
            activeTrackColor: AppColors.bookGreen,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.bookGreen : AppColors.faint,
        boxShadow: online
            ? [BoxShadow(color: AppColors.bookGreen.withValues(alpha: .4), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Driver vehicle;

  /// Stored vehicle photo — same treatment as the account-section thumbnail:
  /// placeholder car icon without/broken URL, silent degrade, no crash.
  Widget _vehiclePhotoThumb(String? rawPhoto, MotoTokens tokens) {
    final raw = rawPhoto?.trim() ?? "";
    final url = raw.isEmpty ? null : resolveUploadUrl(raw);
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.amber.withValues(alpha: .14),
        border: Border.all(color: tokens.line),
      ),
      child: url == null
          ? Icon(Icons.directions_car_rounded,
              size: 22, color: tokens.textSecondary)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(Icons.directions_car_rounded,
                  size: 22, color: tokens.textSecondary),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final verified = vehicle.verified;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.inset,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          _vehiclePhotoThumb(vehicle.vehiclePhoto, tokens),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${vehicle.carModel} · ${vehicle.plate}",
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(context.l10n.pricePerKmShort(vehicle.pricePerKm.toStringAsFixed(2)),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: tokens.accentStrong)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: verified ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              verified
                  ? context.l10n.verifiedChip
                  : context.l10n.pendingReviewChip,
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    verified ? const Color(0xFF047857) : AppColors.amberDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleFields {
  const VehicleFields({
    required this.carModel,
    required this.plate,
    required this.licenseNo,
    required this.pricePerKm,
  });

  final String carModel;
  final String plate;
  final String licenseNo;
  final double pricePerKm;
}

/// First-time setup — create-once vehicle profile (`POST /drivers`).
class _VehicleSetupForm extends StatefulWidget {
  const _VehicleSetupForm({required this.submit});

  final Future<void> Function(VehicleFields fields) submit;

  @override
  State<_VehicleSetupForm> createState() => _VehicleSetupFormState();
}

class _VehicleSetupFormState extends State<_VehicleSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _carModel = TextEditingController();
  final _plate = TextEditingController();
  final _license = TextEditingController();
  final _price = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _carModel.dispose();
    _plate.dispose();
    _license.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.submit(VehicleFields(
      carModel: _carModel.text.trim(),
      plate: _plate.text.trim(),
      licenseNo: _license.text.trim(),
      pricePerKm: double.tryParse(_price.text.replaceAll(",", ".")) ?? 0,
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.l10n;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.tokens.line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.setupVehicleTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(s.setupVehicleSubtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextFormField(
              controller: _carModel,
              decoration: InputDecoration(labelText: s.carModelLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _plate,
              decoration: InputDecoration(labelText: s.plateLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _license,
              decoration: InputDecoration(labelText: s.licenseNoLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.pricePerKmLabel),
              validator: (v) =>
                  double.tryParse(v?.replaceAll(",", ".") ?? "") == null
                      ? s.enterNumber
                      : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.saveVehicle),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: const Color(0xFFB91C1C)),
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.couldntLoadDashboard,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink, // amber always carries ink
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

// --- earnings summary + activity (read-only rollup of rides/mine) -----------

/// Today's stats card plus the last-5-rides activity list, fed by the
/// [driverSummaryProvider]. Loading/error/empty follow DESIGN §9.
class _EarningsAndActivity extends ConsumerWidget {
  const _EarningsAndActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(driverSummaryProvider);

    return summary.when(
      loading: () => const _SummarySkeleton(),
      error: (error, _) => _SummaryError(
        message: _messageFor(error, context.l10n),
        onRetry: () => ref.invalidate(driverSummaryProvider),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EarningsCard(summary: data),
          const SizedBox(height: 14),
          _ActivityCard(summary: data),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.summary});

  final DriverSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final rating = summary.avgRating;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: tokens.accentStrong),
              const SizedBox(width: 8),
              Text(l10nOf(context).todayTitle, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: "${summary.completedToday}",
                  label: l10nOf(context).ridesDoneLabel,
                ),
              ),
              Container(width: 1, height: 34, color: tokens.line),
              Expanded(
                child: _Stat(
                  value: rating == null ? "—" : rating.toStringAsFixed(1),
                  label: l10nOf(context).avgRatingLabel,
                  isRating: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.isRating = false,
  });

  final String value;
  final String label;

  /// Rating stats get the star glyph — keyed off data, not the label
  /// string, so localization can't silently drop it.
  final bool isRating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRating) ...[
              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFCD34D)),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: tokensOf(context).accentStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.summary});

  final DriverSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16, color: context.tokens.accentStrong),
              const SizedBox(width: 8),
              Text(context.l10n.recentActivityTitle,
                  style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.recent.isEmpty)
            const _ActivityEmpty()
          else
            for (final (i, ride) in summary.recent.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _ActivityRow(ride: ride),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.l10n;
    final statusColor = historyStatusColor(ride.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                localizedStatusLabel(s, ride.status),
                style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
              ),
            ),
            const Spacer(),
            Text(relativeTimeLabel(ride.createdAt, l10n: s),
                style: theme.textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 8),
        _routeRow(theme, Icons.trip_origin_rounded, AppColors.bookGreen,
            ride.pickupAddress),
        const SizedBox(height: 4),
        _routeRow(theme, Icons.location_on_rounded, AppColors.muted,
            ride.dropoffAddress),
      ],
    );
  }

  Widget _routeRow(ThemeData theme, IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge),
        ),
      ],
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("🗒️", textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(context.l10n.activityEmptyTitle,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            context.l10n.activityEmptyHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// DESIGN §9 loading state — blocky placeholders, no shimmer.
class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 108,
          decoration: BoxDecoration(
            color: context.tokens.inset,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.tokens.line),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: context.tokens.inset,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.tokens.line),
          ),
        ),
      ],
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.passRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.passRed.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.passRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.passRed)),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: onRetry, child: Text(l10nOf(context).retry)),
          ),
        ],
      ),
    );
  }
}
