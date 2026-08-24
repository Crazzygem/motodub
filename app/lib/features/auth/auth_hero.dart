import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/theme/app_theme.dart";

/// Shared login/register field chrome (§5 fields): surface-2 fill, 16 radius,
/// leading icon, line border that turns amber on focus.
InputDecoration authFieldDecoration({
  required String label,
  required IconData icon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: AppColors.surface2,
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.amber, 1.6),
  );
}

/// Login/register hero band: a warm amber gradient that melts into the
/// canvas, carrying the MOTODUB wordmark (Sora 800, letterspaced like the
/// deck-card watermark) and a one-line tagline. Purely presentational.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    this.wordmark = "MOTODUB",
    this.tagline = "Ride smart. Go far.",
  });

  final String wordmark;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFEF3C7), // warn-bg warm top
            AppColors.amber.withValues(alpha: .16),
            AppColors.surface,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            wordmark,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
