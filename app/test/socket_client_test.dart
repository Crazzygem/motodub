import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:duboun/core/api/socket_client.dart";

// Task 4.5 — SocketClient smoke tests. No live server: the socket wiring is
// glue around socket_io_client; what is actually unit-testable is the raw
// payload → typed-stream mapping and the safe lifecycle (construct, send
// before connect, dispose) without any network I/O.
void main() {
  group("SocketClient lifecycle", () {
    test("constructor performs no network I/O and starts disconnected", () {
      final client = SocketClient(baseUrl: "http://127.0.0.1:1", token: "jwt");

      expect(client.isConnected, isFalse);

      client.dispose();
    });

    test(
        "sendLocationUpdate before connect is a silent no-op, not a crash",
        () {
      final client = SocketClient(baseUrl: "http://127.0.0.1:1", token: "jwt");

      expect(() => client.sendLocationUpdate(11.5564, 104.9282), returnsNormally);
      expect(() => client.joinLocationRoom(42), returnsNormally);

      client.dispose();
    });
  });

  group("SocketClient event mapping", () {
    late SocketClient client;
    late Completer<RideEvent> ride;
    late Completer<DriverLocation> location;
    late List<SocketConnectionState> states;

    setUp(() {
      client = SocketClient(baseUrl: "http://127.0.0.1:1", token: "jwt");
      ride = Completer<RideEvent>();
      location = Completer<DriverLocation>();
      states = <SocketConnectionState>[];
      client.rideEvents.listen(ride.complete);
      client.driverLocations.listen(location.complete);
      client.connectionState.listen(states.add);
    });

    tearDown(() => client.dispose());

    test("maps a ride event payload onto the typed ride stream", () async {
      client.handleEvent("ride:requested", {
        "rideId": 7,
        "status": "requested",
        "customerId": 3,
        "driverId": 5,
      });

      final event = await ride.future.timeout(const Duration(seconds: 1));
      expect(event.event, "ride:requested");
      expect(event.rideId, 7);
      expect(event.status, "requested");
      expect(event.customerId, 3);
      expect(event.driverId, 5);
    });

    test("maps driver:location onto the location stream as doubles", () async {
      client.handleEvent("driver:location", {"lat": 11.55, "lng": 104.9});

      final loc = await location.future.timeout(const Duration(seconds: 1));
      expect(loc.lat, 11.55);
      expect(loc.lng, 104.9);
    });

    test("accepts numeric-string coordinates from the wire", () async {
      client.handleEvent("driver:location", {"lat": "11.55", "lng": "104.9"});

      final loc = await location.future.timeout(const Duration(seconds: 1));
      expect(loc.lat, 11.55);
      expect(loc.lng, 104.9);
    });

    test("unknown or malformed events never reach the typed streams", () async {
      client.handleEvent("noise", {"whatever": 1});
      client.handleEvent("driver:location", null);

      // Nothing may arrive within a short grace window.
      await expectLater(
        location.future.timeout(const Duration(milliseconds: 150)),
        throwsA(isA<TimeoutException>()),
      );
      expect(ride.isCompleted, isFalse);
    });

    test("exposes connection state transitions", () async {
      client.handleEvent("__connect", null);
      await Future<void>.delayed(Duration.zero);
      expect(states, contains(SocketConnectionState.connected));

      client.handleEvent("__disconnect", null);
      expect(client.isConnected, isFalse);
    });
  });
}
