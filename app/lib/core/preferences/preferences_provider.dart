import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Persistence keys — Task C profile customization (theme mode + locale).
const _kThemeMode = "prefs.themeMode";
const _kLocale = "prefs.locale";

/// Theme + language preferences, persisted via [SharedPreferences].
/// Loads asynchronously so test harnesses can mock the plugin store
/// (SharedPreferences.setMockInitialValues) without provider overrides;
/// before the first load resolves the app runs light/English.
class PrefsState {
  const PrefsState({this.themeMode = ThemeMode.system, this.locale});
  final ThemeMode themeMode;

  /// Null → follow the system locale (falls back to English).
  final Locale? locale;
}

class PrefsNotifier extends AsyncNotifier<PrefsState> {
  @override
  Future<PrefsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsState(
      themeMode: _decodeThemeMode(prefs.getString(_kThemeMode)),
      locale: _decodeLocale(prefs.getString(_kLocale)),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull ?? const PrefsState();
    state = AsyncData(PrefsState(themeMode: mode, locale: current.locale));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setLocale(Locale? locale) async {
    final current = state.valueOrNull ?? const PrefsState();
    state = AsyncData(PrefsState(themeMode: current.themeMode, locale: locale));
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocale);
    } else {
      await prefs.setString(_kLocale, locale.languageCode);
    }
  }
}

final preferencesProvider =
    AsyncNotifierProvider<PrefsNotifier, PrefsState>(PrefsNotifier.new);

/// Locale the UI should render in right now — English until a preference
/// (or the system locale, once supported locales resolve it) applies.
/// Lets providers localize curated error copy without a BuildContext.
final appLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(preferencesProvider).valueOrNull?.locale ??
      const Locale("en");
});

ThemeMode _decodeThemeMode(String? raw) => switch (raw) {
      "dark" => ThemeMode.dark,
      "light" => ThemeMode.light,
      _ => ThemeMode.system,
    };

Locale? _decodeLocale(String? raw) =>
    raw == null || raw.isEmpty ? null : Locale(raw);
