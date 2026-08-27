import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/api/api_client.dart";
import "../../core/flirty/flirty_copy.dart";
import "../../core/l10n/l10n.dart";
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

/// The deck's visual pose bus. Drag deltas and release-animation ticks are
/// pushed through [apply]; every animated consumer (top-card transforms,
/// peek parallax, swipe wash) listens instead of rebuilding through
/// [SwipeDeck]'s setState — so a drag frame costs transform-layer updates
/// plus one tiny wash repaint, never a card-subtree rebuild.
class _DeckMotion extends ChangeNotifier {
  Offset offset = Offset.zero;
  double angle = 0;
  double fade = 1;

  /// Signed wash ramp, `±clamp(|dx|/110, 0, 1)`: sign picks the tint,
  /// magnitude drives the fade — mirrors the old `_washProgress` math.
  final ValueNotifier<double> washProgress = ValueNotifier(0);

  void apply({
    required Offset offset,
    required double angle,
    required double fade,
  }) {
    this.offset = offset;
    this.angle = angle;
    this.fade = fade;
    final opacity = (offset.dx.abs() / _releaseDistance).clamp(0.0, 1.0);
    washProgress.value = offset.dx < 0 ? -opacity : opacity;
    notifyListeners();
  }

  @override
  void dispose() {
    washProgress.dispose();
    super.dispose();
  }
}

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
  late final _DeckMotion _motion = _DeckMotion();

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
    _anim
      ..addListener(_onAnimTick)
      ..addStatusListener(_onAnimStatus);
  }

  @override
  void dispose() {
    _anim.dispose();
    _motion.dispose();
    super.dispose();
  }

  // --- release handling -----------------------------------------------------

  /// Release tweens stream straight into the pose bus — the animated card
  /// never rebuilds mid-flight either.
  void _onAnimTick() {
    final offsetAnim = _offsetAnim;
    if (offsetAnim == null) return; // reset() noise after completion
    _motion.apply(
      offset: offsetAnim.value,
      angle: _angleAnim!.value,
      fade: _fadeAnim!.value,
    );
  }

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
    _offsetAnim = null;
    _angleAnim = null;
    _fadeAnim = null;
    _flyingDriver = null;
    _anim.reset(); // ticks are guarded — cleared above
    _motion.apply(offset: Offset.zero, angle: 0, fade: 1);
  }

  double get _visualAngle => _angleForDx(_motion.offset.dx);

  /// `rotate(dx/16deg)` from DESIGN.md §6.
  static double _angleForDx(double dx) => dx / 16 * math.pi / 180;

  bool get _busy => _anim.isAnimating;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_busy) return;
    final cur = _motion.offset;
    // Visual applies translate(dx, dy·.35) — y is damped, x drives logic.
    _applyDrag(
      Offset(cur.dx + details.delta.dx, cur.dy + details.delta.dy * .35),
    );
  }

  void _applyDrag(Offset visual) =>
      _motion.apply(offset: visual, angle: _angleForDx(visual.dx), fade: 1);

  void _onPanEnd(DragEndDetails details) {
    if (_busy) return;
    final dx = _motion.offset.dx;
    final vx = details.velocity.pixelsPerSecond.dx;
    final farEnough =
        dx.abs() >= _releaseDistance || vx.abs() >= _releaseVelocity;
    if (!farEnough) return _springBack();

    _flyOut((dx.abs() >= _releaseDistance ? dx.sign : vx.sign).toInt());
  }

  void _springBack() {
    final curved = CurvedAnimation(parent: _anim, curve: _springBackCurve);
    _offsetAnim =
        Tween(begin: _motion.offset, end: Offset.zero).animate(curved);
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
      begin: _motion.offset,
      end: Offset(sign * _flyOutDistance, _motion.offset.dy),
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

  String _messageFor(Object error, AppLocalizations s) {
    if (error is ApiException) return error.message;
    return s.errNetwork;
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider);
    final s = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AspectRatio(
            aspectRatio: 0.74,
            child: deck.when(
              loading: () => const _DeckSkeleton(),
              error: (error, _) => _DeckError(message: _messageFor(error, s)),
              data: (state) {
                final cards = state.cards;
                if (cards.isEmpty) return const _DeckEmpty();
                return Stack(children: [
                  // Peeks painted first (deepest first) so the top card wins.
                  for (var depth = math.min(cards.length - 1, 2); depth >= 1; depth--)
                    _PeekCard(
                      driver: cards[depth],
                      depth: depth,
                      motion: _motion,
                      scale: _peekScale[depth - 1],
                      translateY: _peekTranslateY[depth - 1],
                    ),
                  // Drag frames flow through ListenableBuilder's cached child:
                  // only the Opacity/Transform render objects update, and the
                  // RepaintBoundary keeps the card's baked layer composited
                  // under the new matrix — no subtree rebuild, no repaint.
                  ListenableBuilder(
                    listenable: _motion,
                    child: RepaintBoundary(
                      key: ValueKey(cards.first.id),
                      child: DriverCard(
                        driver: cards.first,
                        overlay: _SwipeWash(_motion),
                      ),
                    ),
                    builder: (_, card) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Opacity(
                        opacity: _motion.fade,
                        child: Transform.translate(
                          offset: _motion.offset,
                          child: Transform.rotate(
                            alignment: Alignment.center,
                            angle: _motion.angle,
                            // The direction wash rides inside DriverCard —
                            // above photo and shade, below watermark/info —
                            // so copy stays readable at full tint (same
                            // layering philosophy as the dark info gradient).
                            child: card,
                          ),
                        ),
                      ),
                    ),
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

// --- swipe-direction wash -----------------------------------------------------

/// Flirty gradient wash — keeps the gradient-only directive (no BOOK/PASS
/// wording). Right = warm Rausch bloom (the "yes, Oun" blush), left = cool
/// muted fade. Ramps with |dx|/110; during fly-out pins at full then fades
/// with card opacity.
///
/// Listenable-driven: only this gradient repaints on drag frames.
class _SwipeWash extends StatelessWidget {
  const _SwipeWash(this._motion);

  final _DeckMotion _motion;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key("deck-swipe-wash"),
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _motion.washProgress,
          builder: (_, progress, _) {
            final books = progress >= 0;
            final isTest = FlirtyCopy.isTest;
            // Flirty prod: Rausch blush vs muted slate; test: original green/red
            final base = isTest
                ? (books ? AppColors.bookGreen : AppColors.passRed)
                : (books ? AppColors.primary : AppColors.muted);
            final mid = isTest
                ? (books ? AppColors.bookGreen : AppColors.passRed)
                : (books ? const Color(0xFFFF6B8A) : const Color(0xFF9CA3AF));
            return Opacity(
              opacity: progress.abs(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:
                        books ? Alignment.centerLeft : Alignment.centerRight,
                    end: books ? Alignment.centerRight : Alignment.centerLeft,
                    colors: isTest
                        ? [
                            base.withValues(alpha: 0),
                            base.withValues(alpha: .6),
                          ]
                        : [
                            base.withValues(alpha: 0),
                            mid.withValues(alpha: books ? .45 : .38),
                            base.withValues(alpha: books ? .58 : .42),
                          ],
                    stops: isTest ? null : const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- peek cards behind the top card -------------------------------------------

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.driver,
    required this.depth,
    required this.motion,
    required this.scale,
    required this.translateY,
  });

  final Driver driver;
  final int depth;
  final _DeckMotion motion;
  final double scale;
  final double translateY;

  /// Task 7.2 parallax peek — leans slightly opposite to the drag, deeper
  /// cards more; clamped so it stays a whisper.
  double get parallaxX {
    const factors = [0.05, 0.09];
    const maxShifts = [6.0, 11.0];
    final shift = -motion.offset.dx * factors[depth - 1];
    return shift.clamp(-maxShifts[depth - 1], maxShifts[depth - 1]);
  }

  @override
  Widget build(BuildContext context) {
    // Same isolation as the top card: per-frame parallax updates only the
    // translate matrix — the baked card layer is composited, never rebuilt.
    return ListenableBuilder(
      listenable: motion,
      child: RepaintBoundary(child: DriverCard(driver: driver)),
      builder: (_, card) => Transform.translate(
        offset: Offset(parallaxX, translateY),
        child: Transform.scale(scale: scale, child: card),
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
        color: context.tokens.inset,
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
    final s = context.l10n;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("🛵", style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        Text(
          FlirtyCopy.noDriversTitle(context),
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          FlirtyCopy.noDriversHint(context),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.tokens.textSecondary),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => ref.read(deckProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(s.refresh),
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
              ?.copyWith(color: context.tokens.textSecondary),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => ref.read(deckProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(context.l10n.retry),
        ),
      ],
    );
  }
}
