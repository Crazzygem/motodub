import "dart:ui";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/api/api_client.dart" show resolveUploadUrl;
import "../../core/l10n/l10n.dart";
import "../../core/models/driver.dart";
import "../../core/theme/app_theme.dart";
import "../shared/photo_viewer.dart";

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
/// gradient shade, optional swipe-direction wash ([overlay]), watermark, then
/// name/rating, car line, ETA + asking rate. Empty/invalid data degrades to
/// placeholders instead of crashing.
class DriverCard extends StatefulWidget {
  const DriverCard({super.key, required this.driver, this.overlay});

  final Driver? driver;

  /// Optional full-card decoration painted above photo and shade but below
  /// every content layer (watermark/avatar/info) — the deck's swipe
  /// direction wash rides here so text stays readable at full tint.
  /// Always rendered behind an IgnorePointer by the card itself.
  final Widget? overlay;

  @override
  State<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<DriverCard> {
  /// Which gallery photo the hero currently shows (tinder-style pager).
  int _photoIndex = 0;

  Driver? get driver => widget.driver;

  @override
  void didUpdateWidget(DriverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different driver slid into this slot — restart at its cover photo.
    if (oldWidget.driver != widget.driver) _photoIndex = 0;
  }

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
              _photo(context),
              // Click-through: the shade must not eat the photo's tap target.
              Positioned.fill(child: IgnorePointer(child: _shade())),
              if (widget.overlay != null)
                Positioned.fill(child: IgnorePointer(child: widget.overlay!)),
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

  /// Card hero: tinder-style pager over the driver's photo gallery
  /// ([Driver.effectiveVehiclePhotos], legacy `vehicle_photo` cover included).
  /// Relative `/uploads/…` URLs resolve against the API base; entries that
  /// aren't usable URLs — or photos that fail to load — degrade silently to
  /// the taxi icon. With at least one usable photo the hero is the tap target:
  /// left/right thirds page through the gallery (wrap-around), the middle
  /// third opens the full-screen viewer at the current photo. Tap-only —
  /// the deck keeps every drag (tap never competes with its pan). A single
  /// photo disables paging but still opens the viewer; no dots then either.
  Widget _photo(BuildContext context) {
    final photos = _galleryPhotos;
    if (photos.isEmpty) return _photoFallback();
    final index = _photoIndex.clamp(0, photos.length - 1).toInt();
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        key: const Key("driver-card-photo"),
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final dx = details.localPosition.dx;
          if (dx < box.maxWidth / 3) {
            _pageBy(-1, photos.length);
          } else if (dx > box.maxWidth * 2 / 3) {
            _pageBy(1, photos.length);
          } else {
            showPhotoViewer(context, resolveUploadUrl(photos[index]));
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: ColorFiltered(
                key: ValueKey(photos[index]),
                colorFilter: const ColorFilter.matrix(_saturation90),
                child: Image.network(
                  resolveUploadUrl(photos[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _photoFallback(),
                ),
              ),
            ),
            if (photos.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                // Dots are chrome, never a tap target.
                child: IgnorePointer(
                  child: _dots(active: index, count: photos.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Gallery the pager shows: server array or the legacy cover, filtered to
  /// usable URLs — broken entries never become tap targets or viewer sources.
  List<String> get _galleryPhotos {
    final all = driver?.effectiveVehiclePhotos ?? const <String>[];
    return [
      for (final raw in all)
        if (_usablePhoto(raw)) raw,
    ];
  }

  bool _usablePhoto(String raw) {
    if (raw.startsWith("/")) return true; // relative server path
    final uri = Uri.tryParse(raw);
    return uri != null && (uri.scheme == "http" || uri.scheme == "https");
  }

  void _pageBy(int delta, int count) {
    if (count <= 1) return; // single photo: prev/next are no-ops
    setState(() => _photoIndex = (_photoIndex + delta + count) % count);
  }

  /// Pager position dots: small white circles, active one amber and wider.
  Widget _dots({required int active, required int count}) {
    return Row(
      key: const Key("driver-card-dots"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            key: Key("driver-card-dot-$i"),
            width: i == active ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == active
                  ? AppColors.amber
                  : Colors.white.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
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