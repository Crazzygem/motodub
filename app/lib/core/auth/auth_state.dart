import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../features/auth/providers.dart";

/// Immutable auth snapshot persisted across restarts.
class AuthState {
  final String? token;
  final String? role;

  const AuthState({this.token, this.role});

  bool get isAuthenticated => token != null && role != null;
}

class TokenStore {
  static const _tokenKey = "auth.token";
  static const _roleKey = "auth.role";

  Future<AuthState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final role = prefs.getString(_roleKey);
    if (token == null || role == null) return null;
    return AuthState(token: token, role: role);
  }

  Future<void> save(AuthState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, state.token!);
    await prefs.setString(_roleKey, state.role!);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }
}

/// Holds the session; login/register/logout mutate it and the router
/// redirect reacts (route by role, or back to /login).
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    return await TokenStore().load() ?? const AuthState();
  }

  String? _friendly(String? code, String? message) {
    if (code == "NETWORK") {
      return "Cannot reach server. Is the backend running?";
    }
    return message ?? "Something went wrong. Please try again.";
  }

  Future<String?> login(String email, String password) async {
    final result = await ref.read(authRepoProvider).login(email, password);
    if (!result.isOk) return _friendly(result.code, result.message);

    final session = result.data!;
    await TokenStore().save(session.state);
    state = AsyncData(session.state);
    return null;
  }

  Future<String?> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String role,
  }) async {
    final result = await ref.read(authRepoProvider).register(
          name: name,
          phone: phone,
          email: email,
          password: password,
          role: role,
        );
    if (!result.isOk) return _friendly(result.code, result.message);

    final session = result.data!;
    await TokenStore().save(session.state);
    state = AsyncData(session.state);
    return null;
  }

  Future<void> logout() async {
    await TokenStore().clear();
    state = const AsyncData(AuthState());
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
