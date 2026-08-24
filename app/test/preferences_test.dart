import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/core/l10n/l10n.dart";
import "package:motodub/core/preferences/preferences_provider.dart";
import "package:motodub/core/theme/app_theme.dart" show buildAppTheme;
import "package:shared_preferences/shared_preferences.dart";

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("preferences provider", () {
    test("defaults to system theme and English locale", () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = await container.read(preferencesProvider.future);
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.locale, isNull);
    });

    test("theme + locale roundtrip through the persisted store", () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(preferencesProvider.future);
      await container
          .read(preferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await container
          .read(preferencesProvider.notifier)
          .setLocale(const Locale("km"));

      // A fresh container re-reads the same mock store — persistence proof.
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      final restored = await container2.read(preferencesProvider.future);

      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.locale, const Locale("km"));
    });
  });

  testWidgets("dark toggle flips MaterialApp brightness instantly",
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, ref, _) {
          final prefs = ref.watch(preferencesProvider).valueOrNull;
          return MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            themeMode: prefs?.themeMode ?? ThemeMode.system,
            home: Builder(builder: (context) {
              final brightness = Theme.of(context).brightness;
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("brightness=$brightness"),
                      Switch(
                        key: const Key("prefs-dark-switch"),
                        value:
                            Theme.of(context).brightness == Brightness.dark,
                        onChanged: (_) => ref
                            .read(preferencesProvider.notifier)
                            .setThemeMode(
                              brightness == Brightness.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("brightness=Brightness.light"), findsOneWidget);

    await tester.tap(find.byKey(const Key("prefs-dark-switch")));
    await tester.pumpAndSettle();

    expect(find.text("brightness=Brightness.dark"), findsOneWidget);
  });

  testWidgets("Khmer catalog renders when locale is km", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale("km"),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(builder: (context) {
          return Scaffold(body: Text(context.l10n.accountTitle));
        }),
      ),
    );
    await tester.pump();

    // "គណនី" — Account in the Khmer catalog.
    expect(find.text("គណនី"), findsOneWidget);
  });

  testWidgets("bare MaterialApp falls back to the English catalog",
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(body: Text(context.l10n.accountTitle));
        }),
      ),
    );
    await tester.pump();

    expect(find.text("Account"), findsOneWidget);
  });
}
