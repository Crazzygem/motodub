import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/error_messages.dart";
import "../../core/models/ride.dart";
import "../../core/theme/app_theme.dart";
import "../booking/booking_provider.dart" show rideRepoProvider;

// DESIGN.md §10.4 history status chips: completed green · cancelled grey ·
// declined grey (muted) · anything still moving keeps the amber brand.
const Map<String, Color> _statusColors = {
  "completed": AppColors.bookGreen,
  "cancelled": AppColors.muted,
  "declined": AppColors.muted,
  "requested": AppColors.amberDeep,
  "accepted": AppColors.amberDeep,
  "en_route": AppColors.amberDeep,
  "in_progress": AppColors.amberDeep,
};

/// Pill color for a ride [status] — DESIGN tokens, exposed for tests.
Color historyStatusColor(String status) =>
    _statusColors[status] ?? AppColors.muted;

/// Capitalized badge label ("en_route" → "En route").
String historyStatusLabel(String status) {
  final words = status.split("_");
  return words
      .map((w) => w.isEmpty ? w : "${w[0].toUpperCase()}${w.substring(1)}")
      .join(" ");
}

String _formatDate(DateTime utc) {
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  final d = utc.toLocal();
  return "${d.day} ${months[d.month - 1]} · "
      "${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}";
}

/// Task 5.2 — one fetch of GET /api/rides/mine plus its render state.
/// Loading is implicit: `rides == null && error == null`.
class HistoryState {
  const HistoryState({this.rides, this.error});

  /// Null until the first load resolves — drives the loading state.
  final List<Ride>? rides;

  /// Mapped, user-facing failure copy from errorMessageFor() — null when idle.
  final String? error;
}

class HistoryNotifier extends AutoDisposeNotifier<HistoryState> {
  /// Set when the container disposes this notifier — awaited repo calls
  /// check it before touching state (this riverpod has no Ref.mounted).
  bool _disposed = false;

  @override
  HistoryState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return const HistoryState();
  }

  Future<void> _load() async {
    // No state write before the await — providers may not mutate while
    // the tree builds; the initial state IS the loading state.
    final result = await ref.read(rideRepoProvider).mine();
    if (_disposed) return;

    if (result.isOk) {
      state = HistoryState(rides: result.data);
      return;
    }
    state = HistoryState(
      rides: state.rides,
      error: errorMessageFor(result.code!, serverMessage: result.message),
    );
  }

  /// RefreshIndicator seam — errors surface in place, never as exceptions.
  Future<void> refresh() => _load();
}

final historyProvider =
    AutoDisposeNotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);

/// Ride history for the signed-in role (§4 /api/rides/mine picks the rows).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text("Your rides", style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(historyProvider.notifier).refresh(),
                child: history.error != null && history.rides == null
                    ? _ErrorView(
                        message: history.error!,
                        onRetry: () =>
                            ref.read(historyProvider.notifier).refresh(),
                      )
                    : history.rides == null
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 3),
                              ),
                            ],
                          )
                        : _Content(rides: history.rides!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.rides});

  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) return const _EmptyView();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: rides.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _RideCard(ride: rides[index]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🧾", style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text("No rides yet", style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                "Your trips will show up here once you book or drive one.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Couldn't load your rides",
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Try again"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});

  final Ride ride;

  /// Opposite-party line — customer view shows the driver (+ vehicle when
  /// present), driver view shows the customer.
  String get _partyLine {
    if (ride.driverName != null) {
      final vehicle = ride.driverPlate == null
          ? ""
          : " · ${ride.driverCarModel} ${ride.driverPlate}";
      return "with ${ride.driverName}$vehicle";
    }
    if (ride.customerName != null) return "for ${ride.customerName}";
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = historyStatusColor(ride.status);
    final date = ride.createdAt == null ? "" : _formatDate(ride.createdAt!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                key: Key("history-badge-${ride.id}"),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  historyStatusLabel(ride.status),
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
              const Spacer(),
              Text(date, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  size: 10, color: AppColors.bookGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ride.pickupAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 10, color: AppColors.passRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ride.dropoffAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge),
              ),
            ],
          ),
          if (_partyLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_partyLine, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}
