import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../features/auth/providers.dart";
import "../models/user.dart";

/// Immutable auth snapshot persisted across restarts.
class AuthState {
  final String? token;
  final String? role;

  /// Display name carried by the login/register session payload — the
  /// customer greeting reads its first word.
  final String? name;

  /// Session email from the same payload — shown on the Account tab. Null
  /// for sessions persisted before this field existed.
  final String? email;

  /// Own phone + avatar URL (Task B profile customization) — carried by the
  /// session payload and reconciled after PATCH /users/me / avatar uploads.
  final String? phone;
  final String? photo;

  const AuthState({
    this.token,
    this.role,
    this.name,
    this.email,
    this.phone,
    this.photo,
  });

  bool get isAuthenticated => token != null && role != null;
}

class TokenStore {
  static const _tokenKey = "auth.token";
  static const _roleKey = "auth.role";
  static const _nameKey = "auth.name";
  static const _emailKey = "auth.email";
  static const _phoneKey = "auth.phone";
  static const _photoKey = "auth.photo";

  Future<AuthState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final role = prefs.getString(_roleKey);
    if (token == null || role == null) return null;
    return AuthState(
      token: token,
      role: role,
      name: prefs.getString(_nameKey),
      email: prefs.getString(_emailKey),
      phone: prefs.getString(_phoneKey),
      photo: prefs.getString(_photoKey),
    );
  }

  Future<void> save(AuthState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, state.token!);
    await prefs.setString(_roleKey, state.role!);
    if (state.name != null) await prefs.setString(_nameKey, state.name!);
    if (state.email != null) await prefs.setString(_emailKey, state.email!);
    if (state.phone != null) await prefs.setString(_phoneKey, state.phone!);
    if (state.photo != null) await prefs.setString(_photoKey, state.photo!);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_tokenKey, _roleKey, _nameKey, _emailKey, _phoneKey, _photoKey]) {
      await prefs.remove(key);
    }
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

  /// Server-truth reconcile (Task B): merge a fresh `User` payload into the
  /// session and persist it.
  Future<void> adoptUser(User user) async {
    final current = state.valueOrNull ?? const AuthState();
    final merged = AuthState(
      token: current.token,
      role: user.role,
      name: user.name,
      email: user.email,
      phone: user.phone,
      photo: user.photo,
    );
    await TokenStore().save(merged);
    state = AsyncData(merged);
  }

  /// PATCH /users/me: optimistic session update first, revert + friendly
  /// message when the server refuses; adopt its truth when it accepts.
  Future<String?> updateProfile({
    required String name,
    required String phone,
  }) async {
    final current = state.valueOrNull ?? const AuthState();
    final optimistic = AuthState(
      token: current.token,
      role: current.role,
      name: name,
      email: current.email,
      phone: phone,
      photo: current.photo,
    );
    state = AsyncData(optimistic);

    final result = await ref.read(userRepoProvider).patchMe(
          name: name,
          phone: phone,
        );
    if (!result.isOk) {
      state = AsyncData(current); // roll the optimistic write back
      return result.message;
    }
    await adoptUser(result.data!);
    return null;
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
