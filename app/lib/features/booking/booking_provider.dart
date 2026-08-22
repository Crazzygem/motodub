import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../../core/api/ride_repo.dart";
import "../auth/providers.dart" show apiClientProvider;

final rideRepoProvider = Provider<RideRepo>(
  (ref) => RideRepo(ref.watch(apiClientProvider)),
);

/// Which pin map taps / drags move next (Task 3.5 step 1).
enum ActivePin { pickup, dropoff }

/// Immutable booking-form snapshot the sheet renders.
class BookingForm {
  const BookingForm({
    this.activePin = ActivePin.pickup,
    LatLng? pickup,
    LatLng? dropoff,
    this.submitting = false,
    this.error,
  })  : pickup = pickup ?? const LatLng(11.5564, 104.9282),
        dropoff = dropoff ?? const LatLng(11.5215, 104.8892);

  final ActivePin activePin;
  final LatLng pickup;
  final LatLng dropoff;
  final bool submitting;

  /// Mapped, user-facing failure copy from errorMessageFor() — null when idle.
  final String? error;

  BookingForm copyWith({
    ActivePin? activePin,
    LatLng? pickup,
    LatLng? dropoff,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) =>
      BookingForm(
        activePin: activePin ?? this.activePin,
        pickup: pickup ?? this.pickup,
        dropoff: dropoff ?? this.dropoff,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class BookingNotifier extends Notifier<BookingForm> {
  @override
  BookingForm build() => const BookingForm();

  void setActivePin(ActivePin pin) =>
      state = state.copyWith(activePin: pin, clearError: true);

  /// Map tap moves whichever pin is currently active.
  void moveActivePin(LatLng point) => movePin(state.activePin, point);

  /// Marker drag moves exactly the dragged pin, whatever is active.
  void movePin(ActivePin pin, LatLng point) => state = state.copyWith(
        pickup: pin == ActivePin.pickup ? point : null,
        dropoff: pin == ActivePin.dropoff ? point : null,
        clearError: true,
      );

  void beginSubmit() =>
      state = state.copyWith(submitting: true, clearError: true);

  void endSubmit({String? error}) =>
      state = state.copyWith(submitting: false, error: error);
}

final bookingProvider =
    NotifierProvider<BookingNotifier, BookingForm>(BookingNotifier.new);
