import "package:flutter/material.dart";

import "../../core/flirty/flirty_copy.dart";
import "../../core/l10n/l10n.dart";
import "../../core/models/ride.dart";
import "../../core/theme/app_theme.dart";

/// The active ride panel: 4-step stepper (DESIGN.md §5 — done=green,
/// active=amber, pending=line) plus the one CTA the current state allows.
/// The labels ARE the wire names' UI voice: start → "On my way",
/// start-ride → "Start ride", complete → "End ride ✓".
class RideControls extends StatelessWidget {
  const RideControls({
    super.key,
    required this.ride,
    this.onStart,
    this.onStartRide,
    this.onComplete,
  });

  final Ride ride;
  final VoidCallback? onStart;
  final VoidCallback? onStartRide;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, step) in flirtySteps(context).indexed) ...[
                if (i > 0) const _StepLine(),
                Expanded(child: _StepDot(step: step, ride: ride)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ride.dropoffAddress,
            style: theme.textTheme.labelLarge,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (ride.status == "accepted")
            _cta(
              context,
              label: FlirtyCopy.onMyWayCta(context),
              background: AppColors.primary,
              onPressed: onStart,
            ),
          if (ride.status == "en_route")
            _cta(
              context,
              label: FlirtyCopy.startRideCta(context),
              background: AppColors.primary,
              onPressed: onStartRide,
            ),
          if (ride.status == "in_progress")
            _cta(
              context,
              label: FlirtyCopy.endRideCta(context),
              background: AppColors.primary,
              onPressed: onComplete,
            ),
          if (ride.status == "completed")
            _cta(
              context,
              label: FlirtyCopy.isTest
                  ? "Completed 🎉"
                  : "${FlirtyCopy.stepDone(context)} 🎉",
              background: AppColors.bookGreen,
              onPressed: null,
            ),
        ],
      ),
    );
  }

  Widget _cta(
    BuildContext context, {
    required String label,
    required Color background,
    VoidCallback? onPressed,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        // Contrast rule: amber carries ink text, green carries white.
        foregroundColor:
            background == AppColors.amber ? AppColors.ink : Colors.white,
        disabledBackgroundColor: background,
        disabledForegroundColor:
            background == AppColors.amber ? AppColors.ink : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// Wire statuses paired with their localized step labels.
List<({String title, String status})> localizedSteps(AppLocalizations s) => [
      (title: s.stepAccepted, status: "accepted"),
      (title: s.stepEnRoute, status: "en_route"),
      (title: s.stepRiding, status: "in_progress"),
      (title: s.stepDone, status: "completed"),
    ];

/// Flirty twin — random pools, BuildContext locale-aware.
List<({String title, String status})> flirtySteps(BuildContext context) => [
      (title: FlirtyCopy.stepAccepted(context), status: "accepted"),
      (title: FlirtyCopy.stepEnRoute(context), status: "en_route"),
      (title: FlirtyCopy.stepRiding(context), status: "in_progress"),
      (title: FlirtyCopy.stepDone(context), status: "completed"),
    ];

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.ride});

  final ({String title, String status}) step;
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final steps = flirtySteps(context);
    final stepIndex = steps.indexWhere((st) => st.status == step.status);
    final rideIndex = steps.indexWhere((st) => st.status == ride.status);
    final reached = rideIndex >= 0 && stepIndex <= rideIndex;
    final isCurrent = stepIndex == rideIndex;

    final color = !reached
        ? tokensOf(context).line
        : isCurrent
            ? AppColors.amber
            : AppColors.bookGreen;

    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            step.title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: reached
                      ? tokensOf(context).textPrimary
                      : tokensOf(context).textTertiary,
                ),
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      margin: const EdgeInsets.only(top: 6),
      color: context.tokens.line,
    );
  }
}
