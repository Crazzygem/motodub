import "dart:ui";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/api/api_client.dart" show resolveUploadUrl;
import "../../core/l10n/l10n.dart";
import "../../core/models/driver.dart";
import "../../core/theme/app_theme.dart";

/// Rating-chip star — DESIGN.md §5 pins this exact amber variant.
const Color _starAmber = Color(0xFFFCD34D);

/// Muted-photo saturation matrix, DESIGN.md §5 `saturate(.9)`.
const List<double> _saturation90 = [
  0.8203, 0.0715, 0.0072, 0, 0, //
  0.0213, 0.9715, 0.0072, 0, 0, //
  0.0213, 0.0715, 0.9072, 0, 0, //
  0, 0, 0, 1, 0,
];

/// The deck showpiece — DESIGN.md §5 "Driver swipe card": full-bleed photo,
/// gradient shade, watermark, then name/rating, car line, ETA + asking rate.
/// Empty/invalid data degrades to placeholders instead of crashing.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver});

  final Driver? driver;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.74,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28), // §4 deck cards
          color: AppColors.ink,
          // Task 7.2 shadow refinement: a tight contact layer under the
          // §4 elevation keeps the card grounded while it moves.
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .18),
              blurRadius: 40,
              offset: const Offset(0, 18), // §4 card elevation
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _photo(),
              Positioned.fill(child: _shade()),
              Positioned(top: 18, left: 18, child: _watermark()),
              Positioned(top: 14, right: 14, child: _avatarCircle()),
              Positioned(left: 18, right: 18, bottom: 18, child: _infoBlock(context)),
            ],
          ),
        ),
      ),
    );
  }

  // --- layers -------------------------------------------------------------

  /// Card hero: the driver's vehicle photo when one was uploaded. Relative
  /// `/uploads/…` URLs resolve against the API base; anything that isn't a
  /// usable URL — or fails to load — degrades silently to the taxi icon.
  Widget _photo() {
    final raw = driver?.vehiclePhoto?.trim();
    if (raw == null || raw.isEmpty) return _photoFallback();
    // Relative server paths start with "/"; anything else must carry a
    // real http(s) scheme or it's broken.
    if (!raw.startsWith("/")) {
      final uri = Uri.tryParse(raw);
      if (uri == null || (uri.scheme != "http" && uri.scheme != "https")) {
        return _photoFallback();
      }
    }
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_saturation90),
      child: Image.network(
        resolveUploadUrl(raw),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoFallback(),
      ),
    );
  }

  /// Small identity circle at the card top: users.photo with an initials
  /// tile fallback (DESIGN §8 — no broken-image icons, ever).
  Widget _avatarCircle() {
    final raw = driver?.photo?.trim();
    final hasPhoto = raw != null &&
        raw.isNotEmpty &&
        (raw.startsWith("/") ||
            raw.startsWith("http://") ||
            raw.startsWith("https://"));
    return Container(
      key: const Key("driver-card-avatar"),
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.ink.withValues(alpha: .55),
        border: Border.all(color: Colors.white.withValues(alpha: .6)),
      ),
      child: hasPhoto
          ? Image.network(
              resolveUploadUrl(raw),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initialsTile(),
            )
          : _initialsTile(),
    );
  }

  Widget _initialsTile() => Center(
        child: Text(
          _initialsFor(driver?.name),
          style: GoogleFonts.sora(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );

  Widget _photoFallback() {
    return const ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Icon(Icons.local_taxi_rounded, size: 44, color: AppColors.faint),
      ),
    );
  }

  /// Gradient shade: transparent→42%, tint 58%, ink .85 at 100% (§5).
  Widget _shade() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color(0x73111827), // tint stop @58%
            Color(0xD9111827), // ink .85 @100%
          ],
          stops: [0.0, 0.42, 0.58, 1.0],
        ),
      ),
    );
  }

  Widget _watermark() {
    return Text(
      "MOTODUB",
      style: GoogleFonts.sora(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Colors.white.withValues(alpha: .75),
        letterSpacing: 3,
      ),
    );
  }

  Widget _infoBlock(BuildContext context) {
    final jakarta = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _nameText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _GlassChip(child: _ratingRow(jakarta)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _carLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: jakarta.labelLarge?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: .85),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GlassChip(child: _etaRow(jakarta, l10nOf(context))),
            _ratePill(jakarta, l10nOf(context)),
          ],
        ),
      ],
    );
  }

  // --- chips & pills ------------------------------------------------------

  Widget _ratingRow(TextTheme jakarta) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: _starAmber),
        const SizedBox(width: 4),
        Text(
          _ratingText(driver?.rating),
          style: jakarta.labelMedium?.copyWith(
            fontSize: 12.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _etaRow(TextTheme jakarta, AppLocalizations s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time_rounded, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          s.etaRow(_etaValue(driver?.etaMinutes, s)),
          style: jakarta.labelMedium?.copyWith(
            fontSize: 12.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _ratePill(TextTheme jakarta, AppLocalizations s) {
    final rate = driver?.pricePerKm;
    final valid = rate != null && rate.isFinite && rate >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        valid
            ? s.pricePerKmShort(rate.toStringAsFixed(2))
            : "—", // invalid rate renders the bare dash (§5 placeholder)
        style: jakarta.labelMedium?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.ink, // contrast rule: amber always carries ink
        ),
      ),
    );
  }

  // --- field formatting (placeholders over crashes) -----------------------

  String get _nameText {
    final name = driver?.name?.trim();
    return (name == null || name.isEmpty) ? "Driver" : name;
  }

  String _ratingText(double? rating) =>
      (rating == null || !rating.isFinite || rating < 0 || rating > 5)
          ? "—"
          : rating.toStringAsFixed(1);

  String get _carLine {
    final car = driver?.carModel.trim() ?? "";
    final plate = driver?.plate.trim() ?? "";
    final parts = <String>[
      if (car.isNotEmpty) car,
      if (plate.isNotEmpty) plate,
    ];
    return parts.isEmpty ? "—" : parts.join(" · ");
  }

  String _etaValue(int? eta, AppLocalizations s) =>
      (eta == null || eta <= 0) ? "—" : s.etaMinutes(eta);

  /// First letters of the first two name words ("Dara Sok" → "DS").
  String _initialsFor(String? name) {
    final words =
        name?.trim().split(RegExp(r"\s+")).where((w) => w.isNotEmpty).toList() ??
            const [];
    if (words.isEmpty) return "?";
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

/// Translucent blurred backing shared by the rating and ETA chips (§5 glass).
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(999),
          ),
          child: child,
        ),
      ),
    );
  }
}