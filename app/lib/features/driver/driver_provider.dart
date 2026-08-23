import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/ride_repo.dart";
import "../../core/api/socket_client.dart";
import "../../core/models/driver.dart";
import "../../core/models/ride.dart";
import "../../core/auth/auth_state.dart" show authProvider;
import "../booking/booking_provider.dart" show rideRepoProvider;
import "../deck/deck_provider.dart"
    show devicePosition, driverRepoProvider, phnomPenhCenter;

/// One Socket.IO session per container (JWT handshake). Screens subscribe to
/// its typed streams; the driver notifier owns the one WS write (heartbeats).
final socketClientProvider = Provider<SocketClient>((ref) {
  final token = ref.watch(authProvider).valueOrNull?.token ?? "";
  final client = SocketClient(token: token);
  ref.onDispose(client.dispose);
  return client;
});

/// Everything the driver's working screen renders: presence, vehicle,
/// the incoming request and the active ride. REST is the source of truth —
/// socket events only trigger refetches or optimistic merges (§6).
class DriverHomeState {
  const DriverHomeState({
    this.online = false,
    this.vehicle,
    this.incoming,
    this.active,
    this.error,
    this.lastCompletedRideId,
  });

  final bool online; // mirrors drivers.online
  final Driver? vehicle; // null → first-time setup form
  final Ride? incoming; // requested-for-me, awaiting Accept/Decline
  final Ride? active; // accepted | en_route | in_progress
  final String? error;

  /// Set when a ride under this driver's control turns `completed` (own
  /// complete tap or socket reconcile) — Task 7.1's one-shot handoff to
  /// /rating/{id}. Cancelled/declined rides never set it.
  final int? lastCompletedRideId;

  bool get hasRide => incoming != null || active != null;
}

/// Heartbeat cadence per §6: one `location:update` every 5s while online.
const _heartbeatPeriod = Duration(seconds: 5);

class DriverNotifier extends AsyncNotifier<DriverHomeState> {
  Timer? _heartbeat;
  StreamSubscription<RideEvent>? _events;

  /// Pull-to-refresh / reconnect reconcile — re-runs the REST boot.
  void refresh() => ref.invalidateSelf();

  @override
  Future<DriverHomeState> build() async {
    ref.onDispose(_teardown);

    final socket = ref.watch(socketClientProvider);
    socket.connect();
    _events = socket.rideEvents.listen(_onEvent);

    // Boot from REST (§6): profile first — NOT_FOUND just means the
    // first-time setup form; anything else is a real failure.
    var online = false;
    Driver? vehicle;
    String? error;

    final profile = await ref.read(driverRepoProvider).me();
    if (profile.isOk) {
      vehicle = profile.data;
      online = vehicle!.online;
    } else if (profile.code != "NOT_FOUND") {
      error = profile.message;
    }

    // Restore any ride that outlived the app (pending request or in-flight).
    Ride? incoming;
    Ride? active;
    final rides = await ref.read(rideRepoProvider).mine();
    if (rides.isOk) {
      for (final ride in rides.data ?? const <Ride>[]) {
        switch (ride.status) {
          case "requested" when incoming == null:
            incoming = ride;
          case "accepted" ||
                "en_route" ||
                "in_progress" when active == null:
            active = ride;
        }
      }
    } else {
      error ??= rides.message;
    }

    if (online) _startHeartbeat();
    return DriverHomeState(
      online: online,
      vehicle: vehicle,
      incoming: incoming,
      active: active,
      error: error,
    );
  }

  /// Online toggle → `PATCH /drivers/online` (server stamps lat/lng +
  /// updated_at). Success starts/stops the heartbeat stream.
  Future<void> toggleOnline(bool value) async {
    final current = state.valueOrNull;
    if (current == null || current.vehicle == null || current.online == value) {
      return;
    }
    state = AsyncData(DriverHomeState(
      online: current.online,
      vehicle: current.vehicle,
      incoming: current.incoming,
      active: current.active,
    ));

    final fix = await devicePosition() ?? phnomPenhCenter;
    final result =
        await ref.read(driverRepoProvider).setOnline(value, lat: fix.lat, lng: fix.lng);
    final base = state.valueOrNull ?? current;

    if (!result.isOk) {
      // Toggle failed — stay in the previous presence, surface why.
      state = AsyncData(DriverHomeState(
        online: base.online,
        vehicle: base.vehicle,
        incoming: base.incoming,
        active: base.active,
        error: result.message,
      ));
      return;
    }

    state = AsyncData(DriverHomeState(
      online: result.data?.online ?? value,
      vehicle: result.data ?? base.vehicle,
      incoming: base.incoming,
      active: base.active,
    ));
    value ? _startHeartbeat() : _stopHeartbeat();
  }

  /// First-time vehicle creation → `POST /drivers`.
  Future<void> submitVehicle({
    required String carModel,
    required String plate,
    required String licenseNo,
    required double pricePerKm,
  }) async {
    final result = await ref.read(driverRepoProvider).createVehicle(
          carModel: carModel,
          plate: plate,
          licenseNo: licenseNo,
          pricePerKm: pricePerKm,
        );

    if (!result.isOk) {
      state = AsyncData(DriverHomeState(error: result.message));
      return;
    }
    state = AsyncData(DriverHomeState(vehicle: result.data));
  }

  Future<void> accept() => _verdict(RideAction.accept);
  Future<void> decline() => _verdict(RideAction.decline);

  /// Per-state advance: start ("On my way"), startRide, complete.
  Future<void> advance(RideAction action) async {
    final current = state.valueOrNull;
    final active = current?.active;
    if (current == null || active == null) return;

    final result = await ref.read(rideRepoProvider).act(active.id, action);
    if (!result.isOk) {
      _fail(current, result.message);
      return;
    }
    final ride = result.data!;
    final finished = ride.status == "completed" || ride.status == "cancelled";
    state = AsyncData(DriverHomeState(
      online: current.online,
      vehicle: current.vehicle,
      incoming: current.incoming,
      active: finished ? null : ride,
      lastCompletedRideId:
          ride.status == "completed" ? ride.id : current.lastCompletedRideId,
    ));
  }

  Future<void> _verdict(RideAction action) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final incoming = current.incoming;
    if (incoming == null) return;

    final result = await ref.read(rideRepoProvider).act(incoming.id, action);
    if (!result.isOk) {
      _fail(current, result.message); // card stays up on RIDE_BUSY_DRIVER etc.
      return;
    }
    final ride = result.data ?? incoming;
    final keepAsActive = action == RideAction.accept && ride.status == "accepted";
    state = AsyncData(DriverHomeState(
      online: current.online,
      vehicle: current.vehicle,
      incoming: null,
      active: keepAsActive ? ride : current.active,
    ));
  }

  /// Socket announcements only announce (§6) — reconcile via REST.
  void _onEvent(RideEvent event) {
    if (event.rideId != null &&
        (event.event == "ride:requested" || event.event == "ride:updated")) {
      _refreshRide(event.rideId!);
    }
  }

  Future<void> _refreshRide(int id) async {
    final result = await ref.read(rideRepoProvider).getById(id);
    if (!result.isOk) return;
    final ride = result.data!;
    final current = state.valueOrNull;
    if (current == null) return;

    switch (ride.status) {
      case "requested":
        // Only take a new request when idle — server enforces one anyway.
        if (current.incoming?.id == id || !current.hasRide) {
          state = AsyncData(DriverHomeState(
            online: current.online,
            vehicle: current.vehicle,
            incoming: ride,
          ));
        }
      case "accepted" || "en_route" || "in_progress":
        if (current.active?.id == id || current.incoming?.id == id) {
          state = AsyncData(DriverHomeState(
            online: current.online,
            vehicle: current.vehicle,
            active: ride,
          ));
        }
      default: // declined | cancelled | completed — drop it from view
        if (current.incoming?.id == id || current.active?.id == id) {
          state = AsyncData(DriverHomeState(
            online: current.online,
            vehicle: current.vehicle,
            // Admin/customer-side completion still owes the driver their
            // rating handoff; cancellations never navigate.
            lastCompletedRideId:
                ride.status == "completed" ? ride.id : current.lastCompletedRideId,
          ));
        }
    }
  }

  void _fail(DriverHomeState? current, String? message) {
    state = AsyncData(DriverHomeState(
      online: current?.online ?? false,
      vehicle: current?.vehicle,
      incoming: current?.incoming,
      active: current?.active,
      error: message,
    ));
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(_heartbeatPeriod, (_) => _sendFix());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _sendFix() async {
    final fix = await devicePosition() ?? phnomPenhCenter;
    ref.read(socketClientProvider).sendLocationUpdate(fix.lat, fix.lng);
  }

  void _teardown() {
    _stopHeartbeat();
    _events?.cancel();
    _events = null;
  }
}

final driverProvider =
    AsyncNotifierProvider<DriverNotifier, DriverHomeState>(DriverNotifier.new);
