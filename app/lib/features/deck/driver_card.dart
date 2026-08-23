import "dart:ui";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

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
              Positioned(left: 18, right: 18, bottom: 18, child: _infoBlock(context)),
            ],
          ),
        ),
      ),
    );
  }

  // --- layers -------------------------------------------------------------

  Widget _photo() {
    final url = driver?.photo?.trim();
    if (url == null || url.isEmpty) return _photoFallback();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != "http" && uri.scheme != "https")) {
      return _photoFallback();
    }
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_saturation90),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoFallback(),
      ),
    );
  }

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
        Row(
          children: [
            _GlassChip(child: _etaRow(jakarta)),
            const SizedBox(width: 8),
            _ratePill(jakarta),
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

  Widget _etaRow(TextTheme jakarta) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time_rounded, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          "ETA ${_etaText(driver?.etaMinutes)}",
          style: jakarta.labelMedium?.copyWith(
            fontSize: 12.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _ratePill(TextTheme jakarta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _rateText(driver?.pricePerKm),
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

  String _etaText(int? eta) => (eta == null || eta <= 0) ? "—" : "$eta min";

  String _rateText(double? rate) =>
      (rate == null || !rate.isFinite || rate < 0)
          ? "—"
          : "${rate.toStringAsFixed(2)} /km";
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