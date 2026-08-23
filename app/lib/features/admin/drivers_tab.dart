import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/admin_repo.dart";
import "../../core/theme/app_theme.dart";
import "admin_screen.dart" show adminRepoProvider;

// DESIGN.md §2 admin chip tokens (not core AppColors — admin-only shades):
// verified ok-bg/#047857 · pending warn-bg/#B45309 · suspended bad-bg/#B91C1C.
const _okBg = Color(0xFFD1FAE5);
const _okFg = Color(0xFF047857);
const _warnBg = Color(0xFFFEF3C7);
const _warnFg = Color(0xFFB45309);
const _badBg = Color(0xFFFEE2E2);
const _badFg = Color(0xFFB91C1C);

/// One fetch of GET /api/admin/drivers plus its render state. Loading is
/// implicit: `drivers == null && error == null` (history_screen convention).
class DriversState {
  const DriversState({this.drivers, this.error});

  final List<AdminDriver>? drivers;

  /// Mapped, user-facing failure copy — null when idle.
  final String? error;
}

class DriversNotifier extends AutoDisposeNotifier<DriversState> {
  /// Set when the container disposes this notifier — awaited repo calls
  /// check it before touching state (this riverpod has no Ref.mounted).
  bool _disposed = false;

  @override
  DriversState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return const DriversState();
  }

  /// Pull-to-refresh seam.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    // No state write before the await — the initial state IS loading.
    final result = await ref.read(adminRepoProvider).drivers();
    if (_disposed) return;

    if (result.isOk) {
      state = DriversState(drivers: result.data);
      return;
    }
    state = DriversState(drivers: state.drivers, error: result.message);
  }

  /// Modal-confirmed action (PROJECT.md §6: verification and destructive
  /// actions both live behind confirm dialogs). Optimistic chip flip from
  /// the server's row, then a silent reconcile against fresh truth.
  Future<void> runAction(AdminDriver row, {required bool verify}) async {
    final result = verify
        ? await ref.read(adminRepoProvider).verifyDriver(row.driverId)
        : await ref.read(adminRepoProvider).suspendDriver(row.driverId);
    if (_disposed) return;

    if (!result.isOk) {
      state = DriversState(drivers: state.drivers, error: result.message);
      return;
    }

    final updated = result.data!;
    final rows = [...(state.drivers ?? const <AdminDriver>[])];
    final index = rows.indexWhere((d) => d.driverId == updated.driverId);
    if (index >= 0) rows[index] = updated;
    state = DriversState(drivers: rows);

    await _load();
  }
}

final driversProvider =
    AutoDisposeNotifierProvider<DriversNotifier, DriversState>(
  DriversNotifier.new,
);

/// Task 6.2 step 2 — driver verification table. Approve shows for unverified
/// rows, Suspend for active accounts; BOTH open a confirm dialog first.
class DriversTab extends ConsumerWidget {
  const DriversTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(driversProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(driversProvider.notifier).refresh(),
      child: drivers.error != null && drivers.drivers == null
          ? _ErrorView(
              message: drivers.error!,
              onRetry: () => ref.read(driversProvider.notifier).refresh(),
            )
          : drivers.drivers == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 140),
                    Center(child: CircularProgressIndicator(strokeWidth: 3)),
                  ],
                )
              : _Content(rows: drivers.drivers!),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.rows});

  final List<AdminDriver> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) return const _EmptyView();
    final bannerError = ref.watch(
      driversProvider.select((s) => s.drivers == null ? s.error : null),
    );

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: rows.length + (bannerError == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (bannerError != null && index == rows.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              bannerError,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.passRed),
            ),
          );
        }
        return _DriverRow(row: rows[index]);
      },
    );
  }
}

class _DriverRow extends ConsumerWidget {
  const _DriverRow({required this.row});

  final AdminDriver row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (chipLabel, chipBg, chipFg) = _statusChip(row);

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
              Expanded(
                child: Text(row.name,
                    style: theme.textTheme.titleMedium),
              ),
              _Pill(label: chipLabel, bg: chipBg, fg: chipFg),
              const SizedBox(width: 6),
              _onlineChip(),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.email, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _warnBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "\$${row.pricePerKm.toStringAsFixed(2)}/km",
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: _warnFg, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text("★ ${row.rating.toStringAsFixed(1)}",
                  style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: Key("approve-${row.driverId}"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: row.verified
                      ? null
                      : () => _confirmAndRun(context, ref,
                          title: "Approve driver",
                          body: "Approve ${row.name}? They will start "
                              "receiving ride requests.",
                          confirmLabel: "Approve",
                          confirmColor: AppColors.ink,
                          verify: true),
                  child: const Text("Approve"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: Key("suspend-${row.driverId}"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.passRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: !row.active
                      ? null
                      : () => _confirmAndRun(context, ref,
                          title: "Suspend driver",
                          body: "Suspend ${row.name}? Their account will be "
                              "blocked from new bookings.",
                          confirmLabel: "Suspend",
                          confirmColor: AppColors.passRed,
                          verify: false),
                  child: const Text("Suspend"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onlineChip() => _Pill(
        label: row.online ? "Online" : "Offline",
        bg: row.online ? AppColors.bookGreen.withValues(alpha: .14) : AppColors.line,
        fg: row.online ? AppColors.bookGreen : AppColors.muted,
      );

  (String, Color, Color) _statusChip(AdminDriver d) {
    if (!d.active) return ("Suspended", _badBg, _badFg);
    if (d.verified) return ("Verified", _okBg, _okFg);
    return ("Pending", _warnBg, _warnFg);
  }

  /// PROJECT.md §6 / DESIGN.md §5 — the modal IS the gate: no repo call on
  /// the button tap itself, only after explicit confirmation.
  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
    required bool verify,
  }) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: theme.textTheme.titleMedium),
        content: Text(body, style: theme.textTheme.bodyLarge),
        actions: [
          TextButton(
            key: const Key("dialog-cancel"),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            key: const Key("dialog-confirm"),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(driversProvider.notifier).runAction(row, verify: verify);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
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
              const Text("🏍️", style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text("No drivers yet", style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                "Driver profiles will show up here once they sign up.",
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
              Text("Couldn't load drivers", style: theme.textTheme.titleMedium),
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
