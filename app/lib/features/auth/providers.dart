import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/api_client.dart";
import "../../core/api/auth_repo.dart";
import "../../core/auth/auth_state.dart" show authProvider;

/// One client per app; every request re-reads the session token so
/// login/logout take effect without recreating anything (§5).
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokenProvider: () => ref.read(authProvider).valueOrNull?.token,
  ),
);

final authRepoProvider = Provider<AuthRepo>(
  (ref) => AuthRepo(ref.watch(apiClientProvider)),
);
