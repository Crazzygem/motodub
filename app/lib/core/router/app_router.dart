import "package:go_router/go_router.dart";

import "../../features/admin/admin_screen.dart";
import "../../features/customer/customer_home_screen.dart";
import "../../features/driver/driver_home_screen.dart";
import "../../features/auth/login_screen.dart";

/// Phase 1 replaces this stub with real auth state (token + role from
/// shared_preferences). Until then nobody is authenticated → everyone lands
/// on /login.
bool _isAuthenticated() => false;

final appRouter = GoRouter(
  initialLocation: "/login",
  redirect: (context, state) {
    final loggedIn = _isAuthenticated();
    if (!loggedIn) {
      return state.matchedLocation == "/login" ? null : "/login";
    }
    // Authenticated role routing arrives in Phase 1 (route by token role).
    return null;
  },
  routes: [
    GoRoute(path: "/login", builder: (_, _) => const LoginScreen()),
    GoRoute(path: "/customer", builder: (_, _) => const CustomerHomeScreen()),
    GoRoute(path: "/driver", builder: (_, _) => const DriverHomeScreen()),
    GoRoute(path: "/admin", builder: (_, _) => const AdminScreen()),
  ],
);
