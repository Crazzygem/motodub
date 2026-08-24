import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/auth/auth_state.dart";
import "../../core/theme/app_theme.dart";

/// Shared logout pill — the admin header still carries one; every other
/// shell reaches logout through its Account tab.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.tonal(
      onPressed: () => ref.read(authProvider.notifier).logout(),
      child: const Text("Log out"),
    );
  }
}

/// Session identity for the Account tab: initials avatar, name, email and
/// a role chip in the ADMIN-badge style, plus the logout action. Shared by
/// the customer and driver shells.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(authProvider).valueOrNull ?? const AuthState();
    final name = session.name;
    final email = session.email;
    final role = (session.role ?? "").toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text("Account", style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.amber.withValues(alpha: .14),
                        ),
                        child: Text(
                          _initialsFor(name),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.amberDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name ?? "Signed in",
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              email ?? "—",
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.amberDeep,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(width: double.infinity, child: LogoutButton()),
          ],
        ),
      ),
    );
  }
}

/// First letters of the first two name words ("Dara Sok" → "DS").
String _initialsFor(String? name) {
  final words =
      name?.trim().split(RegExp(r"\s+")).where((w) => w.isNotEmpty).toList() ??
          const [];
  if (words.isEmpty) return "?";
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}
