import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/socket_client.dart";
import "../../core/models/ride.dart";
import "../../core/theme/app_theme.dart";
import "../booking/booking_provider.dart" show rideRepoProvider;
import "../driver/driver_provider.dart" show socketClientProvider;
import "../rides/history_screen.dart"
    show historyStatusColor, historyStatusLabel;
import "admin_screen.dart" show adminRepoProvider;

/// Feed filter values — `all` fetches without ?status=.
const List<String> kAdminRideFilters = [
  "all",
  "requested",
  "accepted",
  "en_route",
  "in_progress",
  "completed",
  "cancelled",
  "declined",
];

/// One filtered fetch of GET /api/admin/rides plus its render state.
/// Loading is implicit: `rides == null && error == null`.
class RidesState {
  const RidesState({this.rides, this.error});

  final List<Ride>? rides;
  final String? error;
}

/// Task 6.2 step 3 — the live feed. REST boots and reconciles (§6 golden
/// rule); `ride:updated` announcements arriving on the shared rideEvents
/// stream (the server auto-joins role=admin to the `admin` room at
/// handshake) flip listed rows in place or append unknown ones via a
/// one-ride REST fetch.
class RidesNotifier extends AutoDisposeNotifier<RidesState> {
  bool _disposed = false;
  StreamSubscription<RideEvent>? _events;
  String _filter = "all";

  @override
  RidesState build() {
    _disposed = false;
    _filter = "all";
    ref.onDispose(() {
      _disposed = true;
      _events?.cancel();
      _events = null;
    });

    final socket = ref.watch(socketClientProvider);
    socket.connect();
    _events = socket.rideEvents.listen(_onEvent);

    _load();
    return const RidesState();
  }

  void setFilter(String filter) {
    if (filter == _filter) return;
    _filter = filter;
    state = const RidesState(); // switching filters re-enters loading
    _load();
  }

  /// Pull-to-refresh seam.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final result = await ref.read(adminRepoProvider).rides(
          status: _filter == "all" ? null : _filter,
        );
    if (_disposed) return;

    if (result.isOk) {
      state = RidesState(rides: result.data);
      return;
    }
    state = RidesState(rides: state.rides, error: result.message);
  }

  void _onEvent(RideEvent event) {
    if (event.event != "ride:updated") return;
    final rideId = event.rideId;
    final status = event.status;
    if (rideId == null || status == null) return;

    final rides = state.rides;
    if (rides == null) return; // still loading — next refresh covers it

    final index = rides.indexWhere((r) => r.id == rideId);
    if (index >= 0) {
      if (!_filterMatches(status)) {
        // The ride left the currently viewed slice.
        state = RidesState(rides: [...rides]..removeAt(index));
      } else if (rides[index].status != status) {
        final updated = [...rides];
        updated[index] = _withStatus(rides[index], status);
        state = RidesState(rides: updated);
      }
      return;
    }

    if (!_filterMatches(status)) return;
    _appendFetched(rideId);
  }

  /// Unknown ride → the announcement is only an id+status, so pull the full
  /// row from REST before appending (newest first).
  Future<void> _appendFetched(int rideId) async {
    final result = await ref.read(rideRepoProvider).getById(rideId);
    if (_disposed || !result.isOk) return;
    if (!_filterMatches(result.data!.status)) return;

    state = RidesState(rides: [result.data!, ...state.rides ?? const <Ride>[]]);
  }

  bool _filterMatches(String? status) =>
      _filter == "all" || _filter == status;
}

/// Immutable-ish status merge — Ride carries identity fields the merge must
/// not lose; a hand-rolled copy keeps the model parse-only (no setters).
/// (Same shape as tracking_provider's private helper.)
Ride _withStatus(Ride ride, String status) => Ride(
      id: ride.id,
      customerId: ride.customerId,
      driverId: ride.driverId,
      status: status,
      pickupLat: ride.pickupLat,
      pickupLng: ride.pickupLng,
      pickupAddress: ride.pickupAddress,
      dropoffLat: ride.dropoffLat,
      dropoffLng: ride.dropoffLng,
      dropoffAddress: ride.dropoffAddress,
      fare: ride.fare,
      customerRating: ride.customerRating,
      driverRating: ride.driverRating,
      createdAt: ride.createdAt,
      updatedAt: ride.updatedAt,
      customerName: ride.customerName,
      customerAvgRating: ride.customerAvgRating,
      driverName: ride.driverName,
      driverPhone: ride.driverPhone,
      driverCarModel: ride.driverCarModel,
      driverPlate: ride.driverPlate,
    );

final ridesProvider =
    AutoDisposeNotifierProvider<RidesNotifier, RidesState>(RidesNotifier.new);

/// Status-filterable live ride feed (DESIGN.md §5 admin). Newest first —
/// the server sorts.
class RidesTab extends ConsumerStatefulWidget {
  const RidesTab({super.key});

  @override
  ConsumerState<RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends ConsumerState<RidesTab> {
  String _selected = "all";

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(ridesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              for (final filter in kAdminRideFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(historyStatusLabel(filter)),
                    selected: _selected == filter,
                    onSelected: (_) => _applyFilter(filter),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(ridesProvider.notifier).refresh(),
            child: feed.error != null && feed.rides == null
                ? _ErrorView(
                    message: feed.error!,
                    onRetry: () =>
                        ref.read(ridesProvider.notifier).refresh(),
                  )
                : feed.rides == null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 140),
                          Center(
                            child:
                                CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ],
                      )
                    : _Content(rides: feed.rides!),
          ),
        ),
      ],
    );
  }

  void _applyFilter(String filter) {
    setState(() => _selected = filter);
    ref.read(ridesProvider.notifier).setFilter(filter);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.rides});

  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) return const _EmptyView();
    return ListView.separated(
      key: const Key("admin-rides-list"),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
              const Text("🛰️", style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text("No rides here", style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                "Nothing matches this filter right now.",
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
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Couldn't load the feed", style: theme.textTheme.titleMedium),
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

  String get _partyLine {
    final customer = ride.customerName;
    final driver = ride.driverName;
    if (customer != null && driver != null) return "$customer → $driver";
    if (customer != null) return customer;
    if (driver != null) return driver;
    return "";
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = historyStatusColor(ride.status);
    final date = ride.createdAt == null ? "" : _formatDate(ride.createdAt!);
    final party = _partyLine;

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
                key: Key("admin-ride-badge-${ride.id}"),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              Flexible(
                child: Text(
                  date.isEmpty ? "#${ride.id}" : "#${ride.id}  ·  $date",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall,
                ),
              ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge),
              ),
            ],
          ),
          if (party.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(party, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}
