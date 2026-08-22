import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/api_client.dart";
import "../../core/api/auth_repo.dart";

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepoProvider = Provider<AuthRepo>(
  (ref) => AuthRepo(ref.watch(apiClientProvider)),
);
