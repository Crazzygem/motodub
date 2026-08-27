import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/flirty/flirty_copy.dart";
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
/// Flirty tagline is cached per State visit (late final) so polling /
/// rebuilds don't flicker the wording.
class AuthHero extends StatefulWidget {
  const AuthHero({super.key, this.wordmark = "DUBOUN", this.tagline});

  final String wordmark;

  /// Null → random flirty tagline (all 20, Option B), cached per visit.
  final String? tagline;

  @override
  State<AuthHero> createState() => _AuthHeroState();
}

class _AuthHeroState extends State<AuthHero> {
  late final String _cachedFlirty;
  bool _didCache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCache && widget.tagline == null) {
      _cachedFlirty = FlirtyCopy.tagline(context);
      _didCache = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = tokensOf(context);
    final flirtyTagline = widget.tagline ?? (_didCache ? _cachedFlirty : FlirtyCopy.tagline(context));

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
            widget.wordmark,
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
            flirtyTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
