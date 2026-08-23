import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/admin_repo.dart";
import "../../core/theme/app_theme.dart";
import "../auth/providers.dart" show apiClientProvider;
import "../customer/customer_home_screen.dart" show LogoutButton;
import "dashboard_tab.dart";
import "drivers_tab.dart";
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
/// pill tabs (active = ink bg white text), three live tabs. The Phase-1
/// logout affordance stays in the header.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              _PillTabs(),
              const Expanded(
                child: TabBarView(
                  children: [DashboardTab(), DriversTab(), RidesTab()],
                ),
              ),
            ],
          ),
        ),
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
                  "MotoDub",
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
                    "ADMIN",
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

class _PillTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(999),
        ),
        splashBorderRadius: BorderRadius.circular(999),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle:
            Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
        unselectedLabelStyle:
            Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
        tabs: const [
          Tab(text: "Dashboard"),
          Tab(text: "Drivers"),
          Tab(text: "Rides"),
        ],
      ),
    );
  }
}
