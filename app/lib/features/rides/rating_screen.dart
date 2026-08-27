import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/flirty/flirty_copy.dart";
import "../../core/l10n/l10n.dart";
import "../../core/api/error_messages.dart" show localizedErrorFor;
import "../../core/models/ride.dart";
import "../../core/preferences/preferences_provider.dart" show appLocaleProvider;
import "../../core/theme/app_theme.dart";
import "../booking/booking_provider.dart" show rideRepoProvider;

/// DESIGN.md §2 star token — the brighter amber reserved for ratings
/// (`#FCD34D`, the swipe-card rating-chip star), distinct from the CTA amber.
const Color ratingStarColor = Color(0xFFFCD34D);

/// Dwell on the thanks card before auto-exiting (§9: a beat, not a page).
const Duration _thanksDwell = Duration(milliseconds: 1800);

/// Everything the rating screen renders: the completed ride (party snapshot),
/// the chosen stars, submit progress, and the thanks verdict. The server owns
/// the rules (completed-only, once-per-participant); a double-rate comes back
/// as RIDE_INVALID_TRANSITION and is treated as "already thanked", not an error.
class RatingState {
  const RatingState({
    this.ride,
    this.loading = false,
    this.submitting = false,
    this.stars = 0,
    this.error,
    this.thanks = false,
    this.alreadyRated = false,
  });

  final Ride? ride;
  final bool loading;
  final bool submitting;
  final int stars; // 0 = none picked yet

  /// Mapped, user-facing failure copy — null when idle.
  final String? error;
  final bool thanks;
  final bool alreadyRated;

  RatingState copyWith({
    Ride? ride,
    bool? loading,
    bool? submitting,
    int? stars,
    String? error,
    bool clearError = false,
    bool? thanks,
    bool? alreadyRated,
  }) =>
      RatingState(
        ride: ride ?? this.ride,
        loading: loading ?? this.loading,
        submitting: submitting ?? this.submitting,
        stars: stars ?? this.stars,
        error: clearError ? null : (error ?? this.error),
        thanks: thanks ?? this.thanks,
        alreadyRated: alreadyRated ?? this.alreadyRated,
      );
}

/// One instance per rated ride (`ratingProvider(rideId)`). Boots the ride
/// snapshot from REST, then dispatches POST /api/rides/{id}/rate {stars}.
class RatingNotifier extends AutoDisposeFamilyNotifier<RatingState, int> {
  /// Set when the container disposes this notifier — awaited repo calls
  /// check it before touching state (this riverpod has no Ref.mounted).
  bool _disposed = false;

  @override
  RatingState build(int arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load(arg);
    return const RatingState(loading: true);
  }

  /// Error-panel seam — re-runs the REST boot.
  void retry() => ref.invalidateSelf();

  Future<void> _load(int id) async {
    final result = await ref.read(rideRepoProvider).getById(id);
    if (_disposed) return;
    if (!result.isOk) {
      state = RatingState(
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    state = RatingState(ride: result.data);
  }

  void select(int stars) =>
      state = state.copyWith(stars: stars, clearError: true);

  Future<void> submit() async {
    final ride = state.ride;
    if (ride == null || state.stars == 0 || state.submitting || state.thanks) {
      return;
    }

    state = state.copyWith(submitting: true, clearError: true);
    final result =
        await ref.read(rideRepoProvider).rate(ride.id, stars: state.stars);
    if (_disposed) return;

    if (!result.isOk) {
      // §2 invariant 4 — once-per-participant, enforced server-side. A
      // RIDE_INVALID_TRANSITION here means we already rated: thank and
      // close instead of scolding.
      if (result.code == "RIDE_INVALID_TRANSITION") {
        state = state.copyWith(
          submitting: false,
          thanks: true,
          alreadyRated: true,
        );
        return;
      }
      state = state.copyWith(
        submitting: false,
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    state = state.copyWith(
      submitting: false,
      thanks: true,
      ride: result.data,
    );
  }
}

final ratingProvider = NotifierProvider.autoDispose
    .family<RatingNotifier, RatingState, int>(RatingNotifier.new);

/// Task 7.1 — rate the other party after a `completed` ride. Both roles land
/// here ([viewerRole] picks whose snapshot is shown); stars are tap-to-select
/// and the submit fires the §4 rate endpoint.
class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({
    super.key,
    required this.rideId,
    this.viewerRole,
  });

  final int rideId;

  /// Session role of whoever is rating ("customer" | "driver") — decides
  /// which party snapshot to feature. Null renders the driver when present.
  final String? viewerRole;

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  Timer? _autoExit;

  @override
  void dispose() {
    _autoExit?.cancel();
    super.dispose();
  }

  /// Back button / auto-exit: rating is a terminal handoff, so leaving
  /// always lands on the role's dashboard (nothing useful sits beneath a
  /// deep-link either).
  void _exit() {
    _autoExit?.cancel();
    _autoExit = null;
    context.go(widget.viewerRole == "driver" ? "/driver" : "/customer");
  }

  @override
  Widget build(BuildContext context) {
    final rating = ref.watch(ratingProvider(widget.rideId));

    // Arm the dwell timer exactly once, when the thanks card lands.
    if (rating.thanks && _autoExit == null) {
      _autoExit = Timer(_thanksDwell, () {
        if (mounted) _exit();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: switch (rating) {
          RatingState(loading: true, ride: null, error: null) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 3)),
          RatingState(error: final error?, ride: null) => _BootError(
              message: error,
              onRetry: () =>
                  ref.read(ratingProvider(widget.rideId).notifier).retry(),
              onBack: _exit,
            ),
          RatingState(thanks: true) => _ThanksCard(
              alreadyRated: rating.alreadyRated,
              onDone: _exit,
            ),
          _ => _RateForm(
              ride: rating.ride!,
              viewerRole: widget.viewerRole,
              selected: rating.stars,
              submitting: rating.submitting,
              error: rating.error,
              onSelect: (stars) => ref
                  .read(ratingProvider(widget.rideId).notifier)
                  .select(stars),
              onSubmit: () =>
                  ref.read(ratingProvider(widget.rideId).notifier).submit(),
              onBack: _exit,
            ),
        },
      ),
    );
  }
}

// --- party ------------------------------------------------------------------------
({String name, String caption}) _party(
    Ride ride, String? viewerRole, AppLocalizations s, BuildContext context) {
  final ratesRider = viewerRole == "driver";
  final snapshot = ratesRider ? ride.customerName : ride.driverName;
  final name =
      (snapshot == null || snapshot.trim().isEmpty) ? null : snapshot.trim();

  if (name == null) {
    return (
      name: ratesRider ? s.yourRiderFallback : s.yourDriverFallback,
      caption: FlirtyCopy.howWasTrip(context),
    );
  }
  return (
    name: name,
    caption: FlirtyCopy.howWasTripWith(context, name),
  );
}
/// DESIGN.md §8 avatar fallback everywhere: initials tile on an amber
/// gradient, ink letter, white ring — no broken-image icons, ever.
class _PartyAvatar extends StatelessWidget {
  const _PartyAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(colors: [
          ratingStarColor,
          AppColors.amber,
          ratingStarColor,
        ]),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: .35),
            blurRadius: 12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? "?" : name[0].toUpperCase(),
        style: GoogleFonts.sora(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

// --- form -------------------------------------------------------------------------

class _RateForm extends StatefulWidget {
  const _RateForm({
    required this.ride,
    required this.viewerRole,
    required this.selected,
    required this.submitting,
    required this.error,
    required this.onSelect,
    required this.onSubmit,
    required this.onBack,
  });

  final Ride ride;
  final String? viewerRole;
  final int selected;
  final bool submitting;
  final String? error;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  State<_RateForm> createState() => _RateFormState();
}

class _RateFormState extends State<_RateForm> {
  late final String _rateTitle;
  late final ({String name, String caption}) _cachedParty;
  bool _didCache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCache) {
      _rateTitle = FlirtyCopy.rateYourTrip(context);
      _cachedParty = _party(widget.ride, widget.viewerRole, context.l10n, context);
      _didCache = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = _didCache ? _cachedParty : _party(widget.ride, widget.viewerRole, context.l10n, context);
    final rateTitle = _didCache ? _rateTitle : FlirtyCopy.rateYourTrip(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(rateTitle,
                    style: theme.textTheme.titleLarge),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PartyAvatar(name: party.name),
                const SizedBox(height: 16),
                Text(party.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(party.caption,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final n in [1, 2, 3, 4, 5])
                      GestureDetector(
                        onTap: () => widget.onSelect(n),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.star_rounded,
                            key: Key("star-$n"),
                            size: 44,
                            color: n <= widget.selected
                                ? ratingStarColor
                                : tokensOf(context).line,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                if (widget.error != null) ...[
                  _ErrorBanner(message: widget.error!),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  key: const Key("rating-submit"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.ink,
                    disabledBackgroundColor: AppColors.amber.withValues(alpha: .5),
                    disabledForegroundColor: AppColors.ink.withValues(alpha: .6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      widget.selected == 0 || widget.submitting ? null : widget.onSubmit,
                  child: widget.submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.submitRating),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThanksCard extends StatefulWidget {
  const _ThanksCard({required this.alreadyRated, required this.onDone});

  final bool alreadyRated;
  final VoidCallback onDone;

  @override
  State<_ThanksCard> createState() => _ThanksCardState();
}

class _ThanksCardState extends State<_ThanksCard> {
  late final String _thanks;
  late final String _sub;
  bool _didCache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCache) {
      _thanks = FlirtyCopy.thanksTitle(context);
      _sub = widget.alreadyRated
          ? FlirtyCopy.alreadyRatedNote(context)
          : FlirtyCopy.ratingHelpsNote(context);
      _didCache = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.bookGreen, size: 68),
            const SizedBox(height: 14),
            Text(_didCache ? _thanks : FlirtyCopy.thanksTitle(context),
                style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: tokensOf(context).textPrimary)),
            const SizedBox(height: 6),
            Text(
              _didCache
                  ? _sub
                  : (widget.alreadyRated
                      ? FlirtyCopy.alreadyRatedNote(context)
                      : FlirtyCopy.ratingHelpsNote(context)),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: widget.onDone,
              child: Text(l10nOf(context).doneButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key("rating-error-banner"),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.passRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.passRed.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.passRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.passRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(context.l10n.couldntLoadRide,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.l10n.tryAgain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
