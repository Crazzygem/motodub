import { getIo } from "./socket.js";

// Payload contract (Task 4.4): {rideId, status} + participant ids — cheap and
// enough for the client to refetch via REST, which stays the source of truth.
function emitTo(rooms, event, ride) {
  const current = getIo();
  if (!current) return;
  let channel = current;
  for (const room of rooms) channel = channel.to(room);
  channel.emit(event, {
    rideId: ride.id,
    status: ride.status,
    customerId: ride.customer_id,
    driverId: ride.driver_id,
  });
}

/** `requested` → the targeted driver's room only. */
export function emitRideRequested(ride) {
  emitTo([`user:${ride.driver_id}`], "ride:requested", ride);
}

/** `accepted` → the customer's room + the admin live view. */
export function emitRideAccepted(ride) {
  emitTo([`user:${ride.customer_id}`, "admin"], "ride:accepted", ride);
}

/** `declined` → the customer's room ("driver passed"). */
export function emitRideDeclined(ride) {
  emitTo([`user:${ride.customer_id}`], "ride:declined", ride);
}

/** en_route / in_progress / completed / cancelled → both participants + admin. */
export function emitRideUpdated(ride) {
  emitTo(
    [`user:${ride.customer_id}`, `user:${ride.driver_id}`, "admin"],
    "ride:updated",
    ride,
  );
}

const NOTIFY_BY_STATUS = {
  requested: emitRideRequested,
  accepted: emitRideAccepted,
  declined: emitRideDeclined,
};

/**
 * Fired by RideService after every successful transition. Status names the
 * event; anything not requested/accepted/declined is a ride:updated.
 */
export function notifyRide(ride) {
  (NOTIFY_BY_STATUS[ride.status] ?? emitRideUpdated)(ride);
}
