import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/admin/admin_screen.dart";
import "../../features/auth/login_screen.dart";
import "../../features/auth/register_screen.dart";
import "../../features/customer/customer_home_screen.dart";
import "../../features/driver/driver_home_screen.dart";
import "../auth/auth_state.dart";

/// Auth-aware router: no session → /login · session → dashboard by role.
/// (Phase 1 scope: role comes from the JWT; per-route UI gating hardens later.)
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: "/login",
    redirect: (context, state) {
      // wait for the persisted session to load before deciding
      if (auth.isLoading) return null;

      final session = auth.valueOrNull ?? const AuthState();
      final authArea =
          state.matchedLocation == "/login" ||
              state.matchedLocation == "/register";

      if (!session.isAuthenticated) return authArea ? null : "/login";
      if (authArea) return "/${session.role}";
      if (!state.matchedLocation.startsWith("/${session.role}")) {
        return "/${session.role}";
      }
      return null;
    },
    routes: [
      GoRoute(path: "/login", builder: (_, _) => const LoginScreen()),
      GoRoute(path: "/register", builder: (_, _) => const RegisterScreen()),
      GoRoute(
          path: "/customer", builder: (_, _) => const CustomerHomeScreen()),
      GoRoute(path: "/driver", builder: (_, _) => const DriverHomeScreen()),
      GoRoute(path: "/admin", builder: (_, _) => const AdminScreen()),
    ],
  );
});
