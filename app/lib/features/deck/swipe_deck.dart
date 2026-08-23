import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/api/api_client.dart";
import "../../core/models/driver.dart";
import "../../core/theme/app_theme.dart";
import "deck_provider.dart";
import "driver_card.dart";

/// DESIGN.md §6 motion constants — starting calibration (§10: tuned on-device
/// at Task 3.6).
const double _flyOutDistance = 640; // px
const double _flyOutAngleDeg = 34;
const Duration _springBackDuration = Duration(milliseconds: 350);
const Curve _springBackCurve = Cubic(0.2, 0.8, 0.3, 1.2);
const Duration _flyOutDuration = Duration(milliseconds: 450);
const double _releaseDistance = 110; // px
const double _releaseVelocity = 700; // px/s

/// Peek stack, §6: z-order 10/9/8 via paint order, scale .945/.89, y +14/+28.
const List<double> _peekScale = [0.945, 0.89];
const List<double> _peekTranslateY = [14, 28];

/// THE gesture component — drag/fling right to book, left to pass; the stack
/// pops to the next driver. Swipe-left never leaves the device; swipe-right
/// pops the card here and hands the driver to [onSwipedRight] (Task 3.5 wires
/// the booking sheet).
class SwipeDeck extends ConsumerStatefulWidget {
  const SwipeDeck({super.key, this.onSwipedRight, this.onSwipedLeft});

  final ValueChanged<Driver>? onSwipedRight;
  final ValueChanged<Driver>? onSwipedLeft;

  @override
  ConsumerState<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends ConsumerState<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);

  /// Raw pointer delta while dragging — visual applies translate(dx, dy·.35).
  Offset _drag = Offset.zero;

  /// Set only while a release animation runs.
  Animation<Offset>? _offsetAnim;
  Animation<double>? _angleAnim;
  Animation<double>? _fadeAnim;

  /// The card currently flying out — popped when its animation completes.
  Driver? _flyingDriver;
  int _flySign = 1;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener(_onAnimStatus);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // --- release handling -----------------------------------------------------

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final driver = _flyingDriver;
    if (driver != null) {
      final notifier = ref.read(deckProvider.notifier);
      if (_flySign > 0) {
        notifier.swipeRight(driver);
        widget.onSwipedRight?.call(driver);
      } else {
        notifier.swipeLeft(driver);
        widget.onSwipedLeft?.call(driver);
      }
    }
    setState(() {
      _drag = Offset.zero;
      _offsetAnim = null;
      _angleAnim = null;
      _fadeAnim = null;
      _flyingDriver = null;
    });
    _anim.reset();
  }

  Offset get _visualOffset =>
      _offsetAnim?.value ?? Offset(_drag.dx, _drag.dy * .35);

  double get _visualAngle =>
      _angleAnim?.value ?? _angleForDx(_drag.dx.toDouble());

  /// `rotate(dx/16deg)` from DESIGN.md §6.
  static double _angleForDx(double dx) => dx / 16 * math.pi / 180;

  /// Task 7.2 parallax peek — the two peek cards lean slightly opposite to
  /// the drag, deeper cards more. Driven by the visual offset so release
  /// animations carry them home; clamped so it stays a whisper.
  double _peekParallax(int depth) {
    const factors = [0.05, 0.09];
    const maxShifts = [6.0, 11.0];
    final shift = -_visualOffset.dx * factors[depth - 1];
    return shift.clamp(-maxShifts[depth - 1], maxShifts[depth - 1]);
  }

  bool get _busy => _anim.isAnimating;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_busy) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_busy) return;
    final dx = _drag.dx.toDouble();
    final vx = details.velocity.pixelsPerSecond.dx;
    final farEnough =
        dx.abs() >= _releaseDistance || vx.abs() >= _releaseVelocity;
    if (!farEnough) return _springBack();

    _flyOut((dx.abs() >= _releaseDistance ? dx.sign : vx.sign).toInt());
  }

  void _springBack() {
    final curved = CurvedAnimation(parent: _anim, curve: _springBackCurve);
    _offsetAnim =
        Tween(begin: _visualOffset, end: Offset.zero).animate(curved);
    _angleAnim = Tween(begin: _visualAngle, end: 0.0).animate(curved);
    _fadeAnim = ConstantTween(1.0).animate(_anim);
    _anim.duration = _springBackDuration;
    _anim.forward(from: 0);
  }

  void _flyOut(int sign) {
    final driver = _topDriver;
    if (driver == null) return;
    _flySign = sign;
    _flyingDriver = driver;
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _offsetAnim = Tween(
      begin: _visualOffset,
      end: Offset(sign * _flyOutDistance, _visualOffset.dy),
    ).animate(curved);
    _angleAnim = Tween(
      begin: _visualAngle,
      end: sign * _flyOutAngleDeg * math.pi / 180,
    ).animate(curved);
    _fadeAnim = Tween(begin: 1.0, end: 0.0).animate(_anim);
    _anim.duration = _flyOutDuration;
    _anim.forward(from: 0);
  }

  // --- build ----------------------------------------------------------------

  Driver? get _topDriver {
    final cards = ref.watch(deckProvider).value?.cards ?? const <Driver>[];
    return cards.isEmpty ? null : cards.first;
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return "Cannot reach server. Is the backend running?";
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AspectRatio(
            aspectRatio: 0.74,
            child: deck.when(
              loading: () => const _DeckSkeleton(),
              error: (error, _) => _DeckError(message: _messageFor(error)),
              data: (state) {
                final cards = state.cards;
                if (cards.isEmpty) return const _DeckEmpty();
                return Stack(children: [
                  // Peeks painted first (deepest first) so the top card wins.
                  for (var depth = math.min(cards.length - 1, 2); depth >= 1; depth--)
                    _PeekCard(
                      driver: cards[depth],
                      scale: _peekScale[depth - 1],
                      translateY: _peekTranslateY[depth - 1],
                      parallaxX: _peekParallax(depth),
                    ),
                  _TopCard(
                    key: ValueKey(cards.first.id),
                    driver: cards.first,
                    offset: _visualOffset,
                    angle: _visualAngle,
                    fadeOpacity: _fadeAnim?.value ?? 1,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// --- top (draggable) card -----------------------------------------------------

class _TopCard extends StatelessWidget {
  const _TopCard({
    super.key,
    required this.driver,
    required this.offset,
    required this.angle,
    required this.fadeOpacity,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final Driver driver;
  final Offset offset;
  final double angle;
  final double fadeOpacity;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  /// `clamp(|dx|/110, 0, 1)` from DESIGN.md §6.
  double get _overlayOpacity => (offset.dx.abs() / 110).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Opacity(
        opacity: fadeOpacity,
        child: Transform.translate(
          offset: offset,
          child: Transform.rotate(
            alignment: Alignment.center,
            angle: angle,
            child: Stack(
              children: [
                DriverCard(driver: driver),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _StampOverlay(
                      label: "BOOK",
                      color: AppColors.bookGreen,
                      opacity: offset.dx > 0 ? _overlayOpacity : 0,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _StampOverlay(
                      label: "PASS",
                      color: AppColors.passRed,
                      opacity: offset.dx < 0 ? _overlayOpacity : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// BOOK / PASS stamp fading in with drag progress (§6 overlay opacity).
class _StampOverlay extends StatelessWidget {
  const _StampOverlay({
    required this.label,
    required this.color,
    required this.opacity,
  });

  final String label;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Align(
          alignment: const Alignment(0, -0.62),
          child: Transform.rotate(
            angle: label == "BOOK" ? -0.17 : 0.17,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 4),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: .85),
              ),
              child: Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- peek cards behind the top card -------------------------------------------

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.driver,
    required this.scale,
    required this.translateY,
    required this.parallaxX,
  });

  final Driver driver;
  final double scale;
  final double translateY;
  final double parallaxX;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(parallaxX, translateY),
      child: Transform.scale(
        scale: scale,
        child: DriverCard(driver: driver),
      ),
    );
  }
}

// --- states (DESIGN.md §9) ------------------------------------------------------

class _DeckSkeleton extends StatelessWidget {
  const _DeckSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _DeckEmpty extends ConsumerWidget {
  const _DeckEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("🛵", style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        Text(
          "No drivers online",
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "No drivers online right now — pull to refresh",
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => ref.read(deckProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text("Refresh"),
        ),
      ],
    );
  }
}

class _DeckError extends ConsumerWidget {
  const _DeckError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("⚠️", style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => ref.read(deckProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text("Retry"),
        ),
      ],
    );
  }
}
