import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/l10n/l10n.dart";
import "core/preferences/preferences_provider.dart";
import "core/router/app_router.dart";
import "core/theme/app_theme.dart";

class DubOunApp extends ConsumerWidget {
  const DubOunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(preferencesProvider).valueOrNull;

    return MaterialApp.router(
      title: "DubOun",
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: prefs?.themeMode ?? ThemeMode.system,
      locale: prefs?.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

@Deprecated('Use DubOunApp')
typedef MotoDubApp = DubOunApp;
