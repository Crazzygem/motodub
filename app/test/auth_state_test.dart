import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:duboun/core/auth/auth_state.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  test("logout clears the session and the persisted token/role", () async {
    SharedPreferences.setMockInitialValues({
      "auth.token": "jwt-old",
      "auth.role": "customer",
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Session rehydrates from storage…
    final session = await container.read(authProvider.future);
    expect(session.isAuthenticated, isTrue);

    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).valueOrNull?.isAuthenticated, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString("auth.token"), isNull);
    expect(prefs.getString("auth.role"), isNull);

    // Restart simulation: a fresh scope rehydrates nothing.
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    expect((await restarted.read(authProvider.future)).isAuthenticated, isFalse);
  });

  test("the session name persists across restarts", () async {
    SharedPreferences.setMockInitialValues({});

    // Drive a save + rehydrate through the real TokenStore.
    await TokenStore()
        .save(const AuthState(token: "jwt", role: "customer", name: "Dara"));
    final loaded = await TokenStore().load();
    expect(loaded?.name, "Dara");
    expect(loaded?.role, "customer");

    // Logout clears the name too.
    await TokenStore().clear();
    final after = await TokenStore().load();
    expect(after, isNull);
    expect((await SharedPreferences.getInstance()).getString("auth.name"),
        isNull);
  });
}
