import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../../core/api/error_messages.dart" show localizedErrorFor;
import "../../core/api/ride_repo.dart";
import "../../core/api/socket_client.dart";
import "../../core/l10n/l10n.dart" show lookupAppLocalizations;
import "../../core/models/ride.dart";
import "../../core/preferences/preferences_provider.dart"
    show appLocaleProvider;
import "../booking/booking_provider.dart" show rideRepoProvider;
import "../driver/driver_provider.dart" show socketClientProvider;

/// §2 cancel rows, customer side: requested | accepted | en_route.
bool customerMayCancel(String? status) =>
    status == "requested" || status == "accepted" || status == "en_route";

/// Statuses after a match, when the driver card shows and the location
/// room matters (§6: join location:{driverId} once accepted).
const _activeStatuses = ["accepted", "en_route", "in_progress"];

/// Everything the tracking screen renders: the ride (REST boot + socket
/// merges per §6), the last-known live driver position, cancel progress.
class TrackingState {
  const TrackingState({
    this.ride,
    this.loading = false,
    this.error,
    this.canceling = false,
    this.driverPosition,
  });

  final Ride? ride;
  final bool loading;

  /// Mapped, user-facing failure copy from errorMessageFor() — null when idle.
  final String? error;
  final bool canceling;

  /// Last `driver:location` heartbeat — null until the first one lands,
  /// which keeps the live marker hidden (Task 5.1 step 1).
  final LatLng? driverPosition;

  TrackingState copyWith({
    Ride? ride,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? canceling,
    LatLng? driverPosition,
  }) =>
      TrackingState(
        ride: ride ?? this.ride,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        canceling: canceling ?? this.canceling,
        driverPosition: driverPosition ?? this.driverPosition,
      );
}

/// One instance per tracked ride (`trackingProvider(rideId)`). Boots from
/// REST — the source of truth — then merges matching socket announcements;
/// owns nothing about the ride's rules, those live server-side (golden rule).
class TrackingNotifier extends AutoDisposeFamilyNotifier<TrackingState, int> {
  StreamSubscription<RideEvent>? _events;
  StreamSubscription<DriverLocation>? _locations;
  StreamSubscription<SocketConnectionState>? _connections;
  int? _joinedDriverId;

  /// Set when the container disposes this notifier — awaited repo calls
  /// check it before touching state (this riverpod has no Ref.mounted).
  bool _disposed = false;

  @override
  TrackingState build(int arg) {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _teardown();
    });

    final socket = ref.watch(socketClientProvider);
    socket.connect();
    _events = socket.rideEvents.listen(_onRideEvent);
    _locations = socket.driverLocations.listen(_onLocation);
    // §6: on reconnect re-join rooms — the server dropped our membership.
    _connections = socket.connectionState.listen((state) {
      if (state == SocketConnectionState.disconnected) _joinedDriverId = null;
      if (state == SocketConnectionState.connected) _joinLocationRoom();
    });

    _load(arg);
    return const TrackingState(loading: true);
  }

  /// Reconnect reconcile / pull-to-refresh hook — re-runs the REST boot.
  void retry() => ref.invalidateSelf();

  Future<void> _load(int id) async {
    final result = await ref.read(rideRepoProvider).getById(id);
    if (_disposed) return;
    if (!result.isOk) {
      state = TrackingState(
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    state = TrackingState(ride: result.data);
    _joinLocationRoom();
  }

  /// §6 payloads are cheap announcements ({rideId, status}) for THIS ride —
  /// merge them straight into the held row; no state is computed locally.
  void _onRideEvent(RideEvent event) {
    if (event.rideId != state.ride?.id) return;
    final announced = switch (event.event) {
      "ride:accepted" || "ride:declined" || "ride:updated" => event.status,
      _ => null,
    };
    if (announced == null || announced == state.ride?.status) return;

    state = state.copyWith(
      ride: _withStatus(state.ride!, announced),
      clearError: true,
    );
    _joinLocationRoom(); // requested → accepted starts the live marker
  }

  void _onLocation(DriverLocation location) => state = state.copyWith(
        driverPosition: LatLng(location.lat, location.lng),
      );

  void _joinLocationRoom() {
    final ride = state.ride;
    if (ride == null || !_activeStatuses.contains(ride.status)) return;
    if (_joinedDriverId == ride.driverId) return;
    _joinedDriverId = ride.driverId;
    ref.read(socketClientProvider).joinLocationRoom(ride.driverId);
  }

  /// Customer cancel (§2: requested|accepted|en_route). Server re-checks
  /// everything; we gate only to keep the button honest.
  Future<void> cancel() async {
    final ride = state.ride;
    if (ride == null || !customerMayCancel(ride.status) || state.canceling) {
      return;
    }

    state = state.copyWith(canceling: true, clearError: true);
    final result =
        await ref.read(rideRepoProvider).act(ride.id, RideAction.cancel);
    if (_disposed) return;

    if (!result.isOk) {
      state = state.copyWith(
        canceling: false,
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }
    state = state.copyWith(canceling: false, ride: result.data);
  }

  void _teardown() {
    _events?.cancel();
    _locations?.cancel();
    _connections?.cancel();
    _events = null;
    _locations = null;
    _connections = null;
  }
}

final trackingProvider = NotifierProvider.autoDispose
    .family<TrackingNotifier, TrackingState, int>(TrackingNotifier.new);

/// Immutable-ish status merge — Ride carries identity fields the merge must
/// not lose; a hand-rolled copy keeps the model parse-only (no setters).
Ride _withStatus(Ride ride, String status) => Ride(
      id: ride.id,
      customerId: ride.customerId,
      driverId: ride.driverId,
      status: status,
      pickupLat: ride.pickupLat,
      pickupLng: ride.pickupLng,
      pickupAddress: ride.pickupAddress,
      dropoffLat: ride.dropoffLat,
      dropoffLng: ride.dropoffLng,
      dropoffAddress: ride.dropoffAddress,
      fare: ride.fare,
      customerRating: ride.customerRating,
      driverRating: ride.driverRating,
      createdAt: ride.createdAt,
      updatedAt: ride.updatedAt,
      customerName: ride.customerName,
      customerAvgRating: ride.customerAvgRating,
      driverName: ride.driverName,
      driverPhone: ride.driverPhone,
      driverCarModel: ride.driverCarModel,
      driverPlate: ride.driverPlate,
    );
