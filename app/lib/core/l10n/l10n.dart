import "package:flutter/material.dart";

import "../../l10n/generated/app_localizations.dart";
import "../theme/app_theme.dart" show tokensOf, MotoTokens;

export "../../l10n/generated/app_localizations.dart";

/// [AppLocalizations] for the nearest Localizations scope. Widget tests that
/// pump bare MaterialApps without our delegates still get the English
/// catalog via the generated lookup, so copy assertions keep passing.
AppLocalizations l10nOf(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale("en"));

extension L10nContext on BuildContext {
  AppLocalizations get l10n => l10nOf(this);

  /// Brightness-sensitive neutral palette (Task C dark theme).
  MotoTokens get tokens => tokensOf(this);
}

/// "14 Aug · 09:30" style stamp, localized through the ARB month keys.
String shortDateTime(AppLocalizations s, DateTime local) =>
    "${local.day} ${monthName(s, local.month)} · "
    "${local.hour.toString().padLeft(2, "0")}:"
    "${local.minute.toString().padLeft(2, "0")}";

/// "14 Aug" / "14 Aug 2026".
String shortDate(AppLocalizations s, DateTime local,
    {bool withYear = false}) {
  final base = "${local.day} ${monthName(s, local.month)}";
  return withYear ? "$base ${local.year}" : base;
}

String monthName(AppLocalizations s, int month) => switch (month) {
      1 => s.month1,
      2 => s.month2,
      3 => s.month3,
      4 => s.month4,
      5 => s.month5,
      6 => s.month6,
      7 => s.month7,
      8 => s.month8,
      9 => s.month9,
      10 => s.month10,
      11 => s.month11,
      _ => s.month12,
    };
