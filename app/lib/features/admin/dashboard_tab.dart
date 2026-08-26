import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/admin_repo.dart";
import "../../core/api/api_client.dart" show ApiResult;
import "../../core/api/error_messages.dart" show localizedErrorFor;
import "../../core/l10n/l10n.dart";
import "../../core/preferences/preferences_provider.dart" show appLocaleProvider;
import "../../core/theme/app_theme.dart";
import "admin_screen.dart" show adminRepoProvider;

/// Task 6.2 step 1 — dashboard KPIs off GET /api/admin/stats. The result
/// keeps the ApiResult envelope (no exceptions for business errors).
final statsProvider =
    FutureProvider.autoDispose<ApiResult<AdminStats>>(
  (ref) => ref.watch(adminRepoProvider).stats(),
);

/// Bot deployment state for the dashboard card (Seth directive): the
/// manager snapshot plus busy/error flags. Loading is implicit
/// (`status == null && error == null`) — history_screen convention.
class BotsState {
  const BotsState({this.status, this.error, this.busy = false});

  final BotsStatus? status;

  /// Mapped, user-facing failure copy — null when idle.
  final String? error;
  final bool busy;
}

class BotsNotifier extends AutoDisposeNotifier<BotsState> {
  /// Set when the container disposes this notifier — awaited repo calls
  /// check it before touching state (this riverpod has no Ref.mounted).
  bool _disposed = false;

  @override
  BotsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return const BotsState();
  }

  /// Manual-refresh seam — the card never polls on its own.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    // No state write before the await — the initial state IS loading.
    final result = await ref.read(adminRepoProvider).botsStatus();
    if (_disposed) return;

    if (result.isOk) {
      state = BotsState(status: result.data);
      return;
    }
    state = BotsState(
      status: state.status,
      error: localizedErrorFor(
        lookupAppLocalizations(ref.watch(appLocaleProvider)),
        result.code,
        serverMessage: result.message,
      ),
    );
  }

  /// POST /api/admin/bots {count} — adopt the returned wire snapshot as
  /// server truth; failures surface through the card's error line.
  Future<void> start(int count) async {
    state = BotsState(status: state.status, busy: true);
    final result = await ref.read(adminRepoProvider).startBots(count);
    if (_disposed) return;

    if (!result.isOk) {
      state = BotsState(
        status: state.status,
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    state = BotsState(status: result.data);
  }

  /// DELETE /api/admin/bots — the bare `{running:false}` answer carries no
  /// counters, so silently reconcile against a fresh status read.
  Future<void> stop() async {
    state = BotsState(status: state.status, busy: true);
    final result = await ref.read(adminRepoProvider).stopBots();
    if (_disposed) return;

    if (!result.isOk) {
      state = BotsState(
        status: state.status,
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    await _load();
  }
}

final botsProvider =
    AutoDisposeNotifierProvider<BotsNotifier, BotsState>(BotsNotifier.new);

/// "3m 20s" / "1h 05m" / "45s".
String _formatUptime(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  if (h > 0) return "$h h ${m.toString().padLeft(2, "0")} m";
  if (m > 0) return "$m m ${s.toString().padLeft(2, "0")} s";
  return "$s s";
}

/// Dashboard tab — the 2×2 KPI grid (DESIGN.md §5 admin: surface cards,
/// Sora 800 figures, live figure amber-deep) over the bot-deployment card.
/// Loading / error-retry / manual pull-to-refresh per DESIGN §9; the Bots
/// card itself never polls — refresh is the pull or its header button.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait(<Future<Object?>>[
          ref.refresh(statsProvider.future),
          ref.read(botsProvider.notifier).refresh(),
        ]);
      },
      child: stats.when(
        loading: () => const _LoadingView(),
        error: (_, _) => _ErrorView(
          message: context.l10n.errGeneric,
          onRetry: () => ref.invalidate(statsProvider),
        ),
        data: (result) => result.isOk
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _Grid(theme: theme, stats: result.data!),
                  const SizedBox(height: 12),
                  const _BotsCard(),
                ],
              )
            : _ErrorView(
                message: localizedErrorFor(context.l10n, result.code,
                    serverMessage: result.message),
                onRetry: () => ref.invalidate(statsProvider),
              ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.theme, required this.stats});

  final ThemeData theme;
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _KpiCard(
          label: context.l10n.kpiLiveRides,
          value: "${stats.requestedNow}",
          icon: Icons.directions_car_rounded,
          tint: AppColors.amber,
        ),
        _KpiCard(
          label: context.l10n.kpiOnlineDrivers,
          value: "${stats.onlineDrivers}",
          icon: Icons.wifi_rounded,
          tint: AppColors.bookGreen,
        ),
        _KpiCard(
          label: context.l10n.kpiCompletedToday,
          value: "${stats.completedToday}",
          icon: Icons.check_circle_rounded,
          tint: AppColors.amberDeep,
        ),
        _KpiCard(
          label: context.l10n.kpiAvgRatingCard,
          value: stats.avgRating?.toStringAsFixed(2) ?? "—",
          icon: Icons.star_rounded,
          tint: const Color(0xFFFCD34D), // star amber, DESIGN §5
        ),
      ],
    );
  }
}

// DESIGN.md §2 admin chip token pair reused from the drivers tab: verified
// ok-bg/#047857 reads as "healthy", neutral line shade reads as idle.
const _okBg = Color(0xFFD1FAE5);
const _okFg = Color(0xFF047857);

/// Seth directive — bot deployment card: Running/Stopped pill over the
/// uptime / rides-spawned / last-ride lines, a 1|2|3 pair selector and one
/// Start/Stop toggle with busy + error surfaces. Never polls — refresh is
/// manual only (the header button or the tab's pull-to-refresh).
class _BotsCard extends ConsumerStatefulWidget {
  const _BotsCard();

  @override
  ConsumerState<_BotsCard> createState() => _BotsCardState();
}

class _BotsCardState extends ConsumerState<_BotsCard> {
  int _count = 2; // server-side default (count?:1|2|3=2)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.l10n;
    final bots = ref.watch(botsProvider);
    final notifier = ref.read(botsProvider.notifier);
    final status = bots.status;
    final running = status?.running ?? false;

    final lastRideAt = DateTime.tryParse(status?.lastRideAt ?? "")?.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.smart_toy_rounded,
                    size: 16, color: AppColors.amber),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.botsCardTitle, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                key: const Key("bots-refresh"),
                onPressed: bots.busy ? null : notifier.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          if (status == null && bots.error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (status != null) ...[
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: running ? _okBg : tokensOf(context).line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    running ? s.botsRunning : s.botsStopped,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: running ? _okFg : tokensOf(context).textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "${s.botsUptimeLabel} ${_formatUptime(status.uptimeSec)}",
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow(theme, s.botsRidesLabel, "${status.ridesSpawned}"),
            _detailRow(
              theme,
              s.botsLastRideLabel,
              lastRideAt == null ? "—" : shortDateTime(s, lastRideAt),
            ),
          ],
          const SizedBox(height: 10),
          Text(s.botsPairsLabel, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 1, label: const Text("1")),
              ButtonSegment(value: 2, label: const Text("2")),
              ButtonSegment(value: 3, label: const Text("3")),
            ],
            selected: {_count},
            onSelectionChanged: bots.busy
                ? null
                : (selection) => setState(() => _count = selection.first),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key("bots-toggle"),
            style: FilledButton.styleFrom(
              backgroundColor: running ? AppColors.passRed : AppColors.amber,
              foregroundColor: running ? Colors.white : AppColors.ink,
              disabledBackgroundColor:
                  (running ? AppColors.passRed : AppColors.amber)
                      .withValues(alpha: .4),
              disabledForegroundColor:
                  (running ? Colors.white : AppColors.ink).withValues(alpha: .5),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: bots.busy
                ? null
                : () => running ? notifier.stop() : notifier.start(_count),
            child: bots.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(running ? s.botsStopButton : s.botsStartButton),
          ),
          if (bots.error != null) ...[
            const SizedBox(height: 10),
            Text(
              bots.error!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.passRed),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            const SizedBox(width: 12),
            Text(value, style: theme.textTheme.labelLarge),
          ],
        ),
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.tokens.line),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: tint),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: tokensOf(context).accentStrong,
                  ),
                ),
                const SizedBox(height: 3),
                Text(label, style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 140),
        Center(child: CircularProgressIndicator(strokeWidth: 3)),
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
              Text(context.l10n.couldntLoadNumbersTitle,
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
                label: Text(context.l10n.tryAgain),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
