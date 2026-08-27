import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// Design tokens — Airbnb (DESIGN.md v=alpha, 2026-08-27).
/// Single brand voltage Rausch #ff385c on pure white canvas, Inter as
/// open-source substitute for Airbnb Cereal VF per spec note (Inter fallback,
/// line-height tightened 2% on display to match cap height).
abstract final class AppColors {
  // Canvas & surfaces — Airbnb is 90% white
  static const bg = Color(0xFFFFFFFF); // canvas #ffffff
  static const surface = Color(0xFFFFFFFF); // surface-card
  static const surfaceSoft = Color(0xFFF7F7F7);
  static const surfaceStrong = Color(0xFFF2F2F2);
  // Keep legacy names for call sites
  static const surface2 = surfaceSoft;

  // Text
  static const ink = Color(0xFF222222);
  static const body = Color(0xFF3F3F3F);
  static const muted = Color(0xFF6A6A6A);
  static const faint = Color(0xFF929292); // muted-soft
  static const starRating = Color(0xFF222222);

  // Hairlines & borders
  static const line = Color(0xFFDDDDDD); // hairline
  static const lineSoft = Color(0xFFEBEBEB); // hairline-soft
  static const borderStrong = Color(0xFFC1C1C1);
  static const scrim = Color(0xFF000000);

  // Brand — Rausch
  static const primary = Color(0xFFFF385C);
  static const primaryActive = Color(0xFFE00B41);
  static const primaryDisabled = Color(0xFFFFD1DA);
  static const errorText = Color(0xFFC13515);
  static const errorTextHover = Color(0xFFB32505);
  static const luxe = Color(0xFF460479);
  static const plus = Color(0xFF92174D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const legalLink = Color(0xFF428BFF);

  // Sub-brand is never mainline — keep tokens but don't use in App Theme
  // Deprecated aliases — old MotoDub/DubOun code (amber/sky) now maps to Rausch
  @Deprecated('Use primary')
  static const duboun = primary;
  @Deprecated('Use primaryActive')
  static const dubounHover = primaryActive;
  @Deprecated('Use primaryActive')
  static const dubounDeep = primaryActive;
  @Deprecated('Use primary')
  static const amber = primary;
  @Deprecated('Use primaryActive')
  static const amberHover = primaryActive;
  @Deprecated('Use primaryActive')
  static const amberDeep = primaryActive;

  // Functional — keep for ride states
  static const bookGreen = Color(0xFF10B981);
  static const passRed = Color(0xFFEF4444);

  // Chip tints — warm Rausch tint for pending, keep others
  static const warnBg = Color(0xFFFFE8EC); // pale Rausch, was sky #E0F2FE
  static const okBg = Color(0xFFD1FAE5);
  static const badBg = Color(0xFFFEE2E2);
}

/// Spacing — Airbnb 4px base (DESIGN.md spacing)
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const section = 64.0;
}

/// Radii — Airbnb soft system (DESIGN.md rounded)
abstract final class AppRadii {
  static const xs = 4.0;
  static const sm = 8.0; // buttons
  static const md = 14.0; // property cards
  static const lg = 20.0;
  static const xl = 32.0;
  static const full = 9999.0;
}

/// Brightness-sensitive neutral tokens: one ThemeData swap flips canvas/cards/text.
/// Brand hues (Rausch) stay constant across modes.
@immutable
class MotoTokens extends ThemeExtension<MotoTokens> {
  const MotoTokens({
    required this.canvas,
    required this.card,
    required this.line,
    required this.inset,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentStrong,
  });

  final Color canvas; // scaffold background
  final Color card; // cards, sheets, nav bar
  final Color line; // borders, dividers, pending stepper dots
  final Color inset; // inset fields, trip boxes, skeletons
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Rausch-family accent that must stay legible on [card]
  final Color accentStrong;

  static const light = MotoTokens(
    canvas: AppColors.bg,
    card: AppColors.surface,
    line: AppColors.line,
    inset: AppColors.surfaceSoft,
    textPrimary: AppColors.ink,
    textSecondary: AppColors.muted,
    textTertiary: AppColors.faint,
    accentStrong: AppColors.primary,
  );

  static const dark = MotoTokens(
    canvas: Color(0xFF15171B),
    card: Color(0xFF1E2126),
    line: Color(0xFF2A2F36),
    inset: Color(0xFF26292F),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    accentStrong: AppColors.primary,
  );

  @override
  MotoTokens copyWith({
    Color? canvas,
    Color? card,
    Color? line,
    Color? inset,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentStrong,
  }) =>
      MotoTokens(
        canvas: canvas ?? this.canvas,
        card: card ?? this.card,
        line: line ?? this.line,
        inset: inset ?? this.inset,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        accentStrong: accentStrong ?? this.accentStrong,
      );

  @override
  MotoTokens lerp(MotoTokens? other, double t) => other == null
      ? this
      : MotoTokens(
          canvas: Color.lerp(canvas, other.canvas, t)!,
          card: Color.lerp(card, other.card, t)!,
          line: Color.lerp(line, other.line, t)!,
          inset: Color.lerp(inset, other.inset, t)!,
          textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
          textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
          textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
          accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
        );
}

/// Token lookup with a light fallback so bare-MaterialApp widget tests that
/// don't install the extension keep rendering.
MotoTokens tokensOf(BuildContext context) =>
    Theme.of(context).extension<MotoTokens>() ?? MotoTokens.light;

/// Inter as open-source substitute for Airbnb Cereal VF per DESIGN.md note.
/// Display: 22–28 @ 500/600/700, body 14–16 @ 400, buttons 14–16 @ 500.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  const ink = Color(0xFF222222);
  final inkText = dark ? const Color(0xFFF3F4F6) : ink;
  final mutedText = dark ? const Color(0xFF9CA3AF) : AppColors.muted;
  final tokens = dark ? MotoTokens.dark : MotoTokens.light;

  // Inter — closest open substitute for Airbnb Cereal VF. Tighten display
  // line-heights ~2% per spec to match Cereal's cap height.
  final inter = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary, // white on Rausch
      primaryContainer: AppColors.primaryActive,
      secondary: AppColors.primaryActive,
      onSecondary: AppColors.onPrimary,
      error: AppColors.errorText,
      surface: tokens.card,
      onSurface: inkText,
      outline: tokens.line,
      outlineVariant: AppColors.lineSoft,
    ),
    scaffoldBackgroundColor: tokens.canvas,
    extensions: [tokens],
    // Airbnb elevation: single shadow tier or flat — keep nav flat
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.card,
      foregroundColor: inkText,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: inkText,
      ),
    ),
    // Bottom nav: Airbnb product tabs are text + underline, but for the taxi
    // app we keep a Material 3 NavigationBar with Rausch indicator.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: .12),
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : mutedText,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : mutedText,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: tokens.line, width: 1),
      ),
      shadowColor: Colors.black.withValues(alpha: .08),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.primaryDisabled,
        disabledForegroundColor: AppColors.onPrimary,
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.errorText),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.faint,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    textTheme: inter.copyWith(
      // display-xl 28/700 — hero h1
      displaySmall: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.43 * 0.98, // tighten 2% per Cereal→Inter note
        letterSpacing: 0,
        color: inkText,
      ),
      // display-lg 22/500 — listing detail h1
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.18 * 0.98,
        letterSpacing: -0.44,
        color: inkText,
      ),
      // display-md 21/700
      titleMedium: GoogleFonts.inter(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.43,
        color: inkText,
      ),
      // title-md 16/600 — city blocks
      titleSmall: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: inkText,
      ),
      // body-md 16/400
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: dark ? inkText : AppColors.body,
      ),
      // body-sm 14/400 — card meta, dates
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        color: mutedText,
      ),
      // caption 14/500
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.29,
        color: inkText,
      ),
      // caption-sm 13/400 — legal
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.23,
        color: mutedText,
      ),
      // badge 11/600
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.18,
        color: inkText,
      ),
    ),
  );
}
