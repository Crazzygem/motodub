import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/admin_repo.dart";
import "../../core/api/api_client.dart" show ApiResult;
import "../../core/api/error_messages.dart" show genericErrorMessage;
import "../../core/theme/app_theme.dart";
import "admin_screen.dart" show adminRepoProvider;

/// Task 6.2 step 1 — dashboard KPIs off GET /api/admin/stats. The result
/// keeps the ApiResult envelope (no exceptions for business errors).
final statsProvider =
    FutureProvider.autoDispose<ApiResult<AdminStats>>(
  (ref) => ref.watch(adminRepoProvider).stats(),
);

/// Dashboard tab — the 2×2 KPI grid (DESIGN.md §5 admin: surface cards,
/// Sora 800 figures, live figure amber-deep). Loading / error-retry /
/// pull-to-refresh per DESIGN §9.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(statsProvider.future),
      child: stats.when(
        loading: () => const _LoadingView(),
        error: (_, _) => _ErrorView(
          message: genericErrorMessage,
          onRetry: () => ref.invalidate(statsProvider),
        ),
        data: (result) => result.isOk
            ? _Grid(theme: theme, stats: result.data!)
            : _ErrorView(
                message:
                    result.message ?? "Couldn't load today's numbers.",
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _KpiCard(
          label: "Live rides",
          value: "${stats.requestedNow}",
          icon: Icons.directions_car_rounded,
          tint: AppColors.amber,
        ),
        _KpiCard(
          label: "Online drivers",
          value: "${stats.onlineDrivers}",
          icon: Icons.wifi_rounded,
          tint: AppColors.bookGreen,
        ),
        _KpiCard(
          label: "Completed today",
          value: "${stats.completedToday}",
          icon: Icons.check_circle_rounded,
          tint: AppColors.amberDeep,
        ),
        _KpiCard(
          label: "Avg rating",
          value: stats.avgRating?.toStringAsFixed(2) ?? "—",
          icon: Icons.star_rounded,
          tint: const Color(0xFFFCD34D), // star amber, DESIGN §5
        ),
      ],
    );
  }
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
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
                    color: AppColors.amberDeep,
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
              Text("Couldn't load today's numbers",
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
