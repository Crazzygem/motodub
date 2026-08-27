import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/l10n/l10n.dart";
import "../../core/theme/app_theme.dart";

/// leading icon, line border that turns Rausch on focus.
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
}) {
  final tokens = tokensOf(context);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: tokens.inset,
    border: border(tokens.line),
    enabledBorder: border(tokens.line),
    focusedBorder: border(AppColors.primary, 1.6),
  );
}

/// Login/register hero band: a soft Rausch linear gradient (vertical) that
/// melts into the canvas, carrying the DUBOUN wordmark. Matches screenshot
/// [Image #1] — pale pink top, saturated band behind the wordmark, fade to
/// white before the form. Purely presentational.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, this.wordmark = "DUBOUN", this.tagline});

  final String wordmark;

  /// Null → localized default ("Ride smart. Go far.").
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = tokensOf(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDisabled, // uniform pale Rausch top
            tokens.canvas, // white at form edge
          ],
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
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.5,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagline ?? context.l10n.appTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
