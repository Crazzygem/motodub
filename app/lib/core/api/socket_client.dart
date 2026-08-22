import "dart:async";

import "package:socket_io_client/socket_io_client.dart" as sio;

import "api_client.dart";

enum SocketConnectionState { connected, disconnected }

/// §6 realtime contract payload for ride announcements: cheap fields the
/// client uses to refetch via REST (the source of truth).
class RideEvent {
  const RideEvent({
    required this.event,
    this.rideId,
    this.status,
    this.customerId,
    this.driverId,
  });

  final String event;
  final int? rideId;
  final String? status;
  final int? customerId;
  final int? driverId;
}

/// §6 `driver:location` payload for live tracking consumers.
class DriverLocation {
  const DriverLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Socket.IO plumbing shared by later screens (Task 4.5): JWT handshake,
/// auto-reconnect, typed broadcast streams, and the one WS write
/// (`location:update`). REST stays the source of truth — nothing here
/// mutates state server-side except driver telemetry.
class SocketClient {
  SocketClient({this.baseUrl = apiBaseUrl, required this.token});

  final String baseUrl;
  final String token;

  sio.Socket? _socket;
  SocketConnectionState _state = SocketConnectionState.disconnected;

  final _states = StreamController<SocketConnectionState>.broadcast();
  final _rides = StreamController<RideEvent>.broadcast();
  final _locations = StreamController<DriverLocation>.broadcast();

  Stream<SocketConnectionState> get connectionState => _states.stream;
  Stream<RideEvent> get rideEvents => _rides.stream;
  Stream<DriverLocation> get driverLocations => _locations.stream;
  bool get isConnected => _state == SocketConnectionState.connected;

  /// Opens the connection. Safe to call once per session; socket_io_client
  /// re-handshakes automatically on drops (§6: reconnect then refetch REST).
  void connect() {
    if (_socket != null) return;
    _socket = sio.io(
      baseUrl,
      sio.OptionBuilder()
          .setTransports(["websocket"])
          .setAuth({"token": token})
          .enableReconnection()
          .build(),
    )
      ..onConnect((_) => handleEvent("__connect", null))
      ..onDisconnect((_) => handleEvent("__disconnect", null));

    for (final event in const [
      "ride:requested",
      "ride:accepted",
      "ride:declined",
      "ride:updated",
      "driver:location",
    ]) {
      _socket!.on(event, (data) => handleEvent(event, data));
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _setState(SocketConnectionState.disconnected);
  }

  /// The one WS write (§6): driver telemetry every 5s while online.
  /// Silent no-op while disconnected — telemetry never queues up.
  void sendLocationUpdate(double lat, double lng) {
    if (!isConnected) return;
    _socket?.emit("location:update", {"lat": lat, "lng": lng});
  }

  /// §6 room contract: a customer joins `location:{driverId}` once their
  /// ride is accepted so [driverLocations] starts flowing (Task 5.1).
  void joinLocationRoom(int driverId) {
    if (!isConnected) return;
    _socket?.emit("join:location", {"driverId": driverId});
  }

  void dispose() {
    disconnect();
    _states.close();
    _rides.close();
    _locations.close();
  }

  /// Single mapping seam for raw payloads → typed streams. Public only so
  /// tests can verify the parsing rules without a live server — not part
  /// of the screen-facing API.
  void handleEvent(String event, dynamic data) {
    switch (event) {
      case "__connect":
        _setState(SocketConnectionState.connected);
      case "__disconnect":
        _setState(SocketConnectionState.disconnected);
      case "ride:requested":
      case "ride:accepted":
      case "ride:declined":
      case "ride:updated":
        final map = data is Map ? data : null;
        _rides.add(RideEvent(
          event: event,
          rideId: _toInt(map?["rideId"]),
          status: map?["status"] as String?,
          customerId: _toInt(map?["customerId"]),
          driverId: _toInt(map?["driverId"]),
        ));
      case "driver:location":
        final map = data is Map ? data : null;
        final lat = _toDouble(map?["lat"]);
        final lng = _toDouble(map?["lng"]);
        if (lat == null || lng == null) return; // malformed telemetry
        _locations.add(DriverLocation(lat: lat, lng: lng));
      default:
        return; // unknown event — ignore
    }
  }

  void _setState(SocketConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  static int? _toInt(dynamic value) =>
      value is int ? value : (value is num ? value.toInt() : int.tryParse("$value"));

  static double? _toDouble(dynamic value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };
}
