import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/admin_repo.dart";
import "../../core/l10n/l10n.dart";
import "../../core/theme/app_theme.dart";
import "../auth/providers.dart" show apiClientProvider;
import "../account/account_screen.dart" show LogoutButton;
import "dashboard_tab.dart";
import "drivers_tab.dart";
import "live_map_tab.dart";
import "rides_tab.dart";

/// One admin API surface per app session.
final adminRepoProvider = Provider<AdminRepo>(
  (ref) => AdminRepo(ref.watch(apiClientProvider)),
);

// DESIGN.md §2 admin header shades: warn-bg tag on the ink bar — the only
// dark surface in the app (§10 design debt note).
const _warnBg = Color(0xFFFEF3C7);
const _warnFg = Color(0xFFB45309);

/// Task 6.2 — admin shell: ink header with the amber-M mark and ADMIN tag,
/// four live tabs (Task 6.3 added the live map) driven by a Material 3
/// bottom [NavigationBar] (nav restructure). The Phase-1 logout affordance
/// stays in the header — admin has no Account tab, consistent with
/// authority apps.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, this.tileLayer});

  /// Injectable map tile layer — tests pass a stub so nothing touches
  /// network (TrackingScreen convention).
  final Widget? tileLayer;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              Expanded(
                child: TabBarView(
                  children: [
                    const DashboardTab(),
                    const DriversTab(),
                    const RidesTab(),
                    LiveMapTab(tileLayer: tileLayer),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _AdminNav(),
      ),
    );
  }
}

/// Bridges the bottom [NavigationBar] to the shell's [TabController] —
/// selection follows tab animations in both directions.
class _AdminNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    final s = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => NavigationBar(
        selectedIndex: controller.index,
        onDestinationSelected: controller.animateTo,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_rounded),
            label: s.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_rounded),
            label: s.navDrivers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_rounded),
            label: s.navRides,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_rounded),
            label: s.navLiveMap,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "M",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.amber,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DubOun",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _warnBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10nOf(context).adminTag,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _warnFg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const LogoutButton(),
        ],
      ),
    );
  }
}

