import "../auth/auth_state.dart";
import "api_client.dart";

/// Session payload of register/login: the token plus the role it carries.
class AuthSession {
  final String token;
  final String role;
  final String? name;
  final String? email;
  final String? phone;
  final String? photo;

  const AuthSession({
    required this.token,
    required this.role,
    this.name,
    this.email,
    this.phone,
    this.photo,
  });

  AuthState get state => AuthState(
        token: token,
        role: role,
        name: name,
        email: email,
        phone: phone,
        photo: photo,
      );

  static AuthSession fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final user = map["user"] as Map<String, dynamic>;
    return AuthSession(
      token: map["token"] as String,
      role: user["role"] as String,
      name: user["name"] as String?,
      email: user["email"] as String?,
      phone: user["phone"] as String?,
      photo: user["photo"] as String?,
    );
  }
}

class AuthRepo {
  final ApiClient _client;

  AuthRepo(this._client);

  Future<ApiResult<AuthSession>> login(String email, String password) =>
      _client.post<AuthSession>(
        "/api/login",
        body: {"email": email, "password": password},
        parse: AuthSession.fromJson,
      );

  Future<ApiResult<AuthSession>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String role,
  }) =>
      _client.post<AuthSession>(
        "/api/register",
        body: {
          "name": name,
          "phone": phone,
          "email": email,
          "password": password,
          "role": role,
        },
        parse: AuthSession.fromJson,
      );
}
