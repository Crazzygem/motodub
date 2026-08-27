import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// Design tokens — DubOun palette (rebranded from MotoDub Amber 2026-08-27).
/// Neutrals (bg/surface/ink/muted/faint/line) unchanged; brand family now sky.
abstract final class AppColors {
  static const bg = Color(0xFFFAFAF9); // app canvas
  static const surface = Color(0xFFFFFFFF); // cards, sheets, nav
  static const ink = Color(0xFF111827); // primary text, dark elements
  // DubOun brand — sky
  static const duboun = Color(0xFF0EA5E9); // primary brand
  static const dubounHover = Color(0xFF38BDF8);
  static const dubounDeep = Color(0xFF0369A1); // text-on-duboun, active nav
  // Deprecated aliases — keep MotoDub code compiling, all point to DubOun.
  @Deprecated('Use duboun') static const amber = duboun;
  @Deprecated('Use dubounHover') static const amberHover = dubounHover;
  @Deprecated('Use dubounDeep') static const amberDeep = dubounDeep;
  static const bookGreen = Color(0xFF10B981); // BOOK action, success
  static const passRed = Color(0xFFEF4444); // PASS action, destructive
  static const muted = Color(0xFF6B7280); // secondary text
  static const faint = Color(0xFF9CA3AF); // tertiary text, placeholders
  static const line = Color(0xFFE5E7EB); // borders, dividers
  static const surface2 = Color(0xFFF9FAFB); // inset fields, trip boxes
  // Chip tints — warn now sky-tinted to match DubOun
  static const warnBg = Color(0xFFE0F2FE); // was #FEF3C7 amber tint
  static const okBg = Color(0xFFD1FAE5);
  static const badBg = Color(0xFFFEE2E2);
}

/// Brightness-sensitive neutral tokens (Task C dark theme): everything the
/// screens used to read straight off [AppColors] constants now comes from
/// this extension so one ThemeData swap flips canvas/cards/text together.
/// Brand hues (amber/green/red) stay constant across modes and remain on
/// [AppColors].
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

  /// DubOun-family text/icon accent that must stay legible on [card]
  /// (dubounDeep in light, dubounHover in dark).
  final Color accentStrong;

  static const light = MotoTokens(
    canvas: AppColors.bg,
    card: AppColors.surface,
    line: AppColors.line,
    inset: AppColors.surface2,
    textPrimary: AppColors.ink,
    textSecondary: AppColors.muted,
    textTertiary: AppColors.faint,
    accentStrong: AppColors.dubounDeep,
  );

  static const dark = MotoTokens(
    canvas: Color(0xFF15171B),
    card: Color(0xFF1E2126),
    line: Color(0xFF2A2F36),
    inset: Color(0xFF26292F),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    accentStrong: AppColors.dubounHover,
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

/// Typography from DESIGN.md §3 — Sora 800/700 headings, Plus Jakarta Sans body.
/// One builder for both brightnesses: same seeds and fonts, neutrals flip.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  const soraInk = Color(0xFF111827);
  final inkText = dark ? const Color(0xFFF3F4F6) : soraInk;
  final mutedText = dark ? const Color(0xFF9CA3AF) : AppColors.muted;
  final faintText = dark ? const Color(0xFF6B7280) : AppColors.faint;
  final tokens = dark ? MotoTokens.dark : MotoTokens.light;

  final jakarta = GoogleFonts.plusJakartaSansTextTheme();
  final sora = GoogleFonts.soraTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.duboun,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.duboun,
      onPrimary: AppColors.ink, // DubOun sky also carries ink text (light brand)
      secondary: AppColors.dubounDeep,
      onSecondary: Colors.white,
      error: AppColors.passRed,
      surface: tokens.card,
      onSurface: inkText,
      outline: tokens.line,
    ),
    scaffoldBackgroundColor: tokens.canvas,
    extensions: [tokens],
    // Shared M3 bottom-nav chrome for every role shell: DubOun selection
    // (indicator wash + active token icon/label, §2 "active nav" token).
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.duboun.withValues(alpha: .16),
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? tokens.accentStrong
              : mutedText,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? tokens.accentStrong
              : mutedText,
        ),
      ),
    ),
    textTheme: jakarta.copyWith(
      // Headings: Sora (display 26 · screen title 18–20 · card name 16–17)
      displaySmall: sora.displaySmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: inkText,
      ),
      titleLarge: sora.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: inkText,
      ),
      titleMedium: sora.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: inkText,
      ),
      // Body/UI: Plus Jakarta Sans (body 14 · meta 12 · micro 10.5)
      bodyLarge: jakarta.bodyLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: inkText,
      ),
      bodyMedium: jakarta.bodyMedium?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: mutedText,
      ),
      labelLarge: jakarta.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: inkText,
      ),
      labelMedium: jakarta.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: mutedText,
      ),
      labelSmall: jakarta.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: faintText,
      ),
    ),
  );
}
