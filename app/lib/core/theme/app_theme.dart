import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// Design tokens from DESIGN.md §2 (palette) — locked 2026-08-21, Amber direction.
abstract final class AppColors {
  static const bg = Color(0xFFFAFAF9); // app canvas
  static const surface = Color(0xFFFFFFFF); // cards, sheets, nav
  static const ink = Color(0xFF111827); // primary text, dark elements
  static const amber = Color(0xFFF59E0B); // primary brand
  static const amberHover = Color(0xFFFBBF24);
  static const amberDeep = Color(0xFFB45309); // text-on-amber-pill, active nav
  static const bookGreen = Color(0xFF10B981); // BOOK action, success
  static const passRed = Color(0xFFEF4444); // PASS action, destructive
  static const muted = Color(0xFF6B7280); // secondary text
  static const faint = Color(0xFF9CA3AF); // tertiary text, placeholders
  static const line = Color(0xFFE5E7EB); // borders, dividers
  static const surface2 = Color(0xFFF9FAFB); // inset fields, trip boxes
}

/// Typography from DESIGN.md §3 — Sora 800/700 headings, Plus Jakarta Sans body.
ThemeData buildAppTheme() {
  const soraInk = Color(0xFF111827);

  final jakarta = GoogleFonts.plusJakartaSansTextTheme();
  final sora = GoogleFonts.soraTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.amber).copyWith(
      primary: AppColors.amber,
      onPrimary: AppColors.ink, // contrast rule: amber always carries ink text
      secondary: AppColors.amberDeep,
      onSecondary: Colors.white,
      error: AppColors.passRed,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      outline: AppColors.line,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    // Shared M3 bottom-nav chrome for every role shell: amber selection
    // (indicator wash + amberDeep icon/label, §2 "active nav" token).
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.amber.withValues(alpha: .16),
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.amberDeep
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.amberDeep
              : AppColors.muted,
        ),
      ),
    ),
    textTheme: jakarta.copyWith(
      // Headings: Sora (display 26 · screen title 18–20 · card name 16–17)
      displaySmall: sora.displaySmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: soraInk,
      ),
      titleLarge: sora.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: soraInk,
      ),
      titleMedium: sora.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: soraInk,
      ),
      // Body/UI: Plus Jakarta Sans (body 14 · meta 12 · micro 10.5)
      bodyLarge: jakarta.bodyLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: soraInk,
      ),
      bodyMedium: jakarta.bodyMedium?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      ),
      labelLarge: jakarta.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: soraInk,
      ),
      labelMedium: jakarta.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
      labelSmall: jakarta.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: AppColors.faint,
      ),
    ),
  );
}
