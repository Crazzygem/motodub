import { getIo } from "./socket.js";
import { sendPush } from "../push/fcm.js";

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

// §7 dual delivery: every emitted ride event also goes out as an FCM push to
// the same participants, carrying rideId so the app can drop the duplicate.
// (Admin is a socket room, not a device target — the live admin view rides
// the socket; there is no admin user id on the ride row to push to.)
const PUSH_COPY = {
  requested: { title: "New ride request", body: "A customer is waiting for you" },
  accepted: { title: "Ride accepted", body: "Your driver accepted the ride" },
  declined: { title: "Ride declined", body: "The driver passed on your request" },
  en_route: { title: "Driver on the way", body: "Your driver is heading to pickup" },
  in_progress: { title: "Ride started", body: "Enjoy your ride" },
  completed: { title: "Ride completed", body: "Thanks for riding with MotoDub" },
  cancelled: { title: "Ride cancelled", body: "Your ride was cancelled" },
};

function pushTo(userIds, status, ride) {
  const copy = PUSH_COPY[status];
  if (!copy) return;
  for (const id of userIds) {
    void sendPush(id, { ...copy, rideId: ride.id });
  }
}

/** `requested` → the targeted driver's room only. */
export function emitRideRequested(ride) {
  emitTo([`user:${ride.driver_id}`], "ride:requested", ride);
  pushTo([ride.driver_id], ride.status, ride);
}

/** `accepted` → the customer's room + the admin live view. */
export function emitRideAccepted(ride) {
  emitTo([`user:${ride.customer_id}`, "admin"], "ride:accepted", ride);
  pushTo([ride.customer_id], ride.status, ride);
}

/** `declined` → the customer's room ("driver passed"). */
export function emitRideDeclined(ride) {
  emitTo([`user:${ride.customer_id}`], "ride:declined", ride);
  pushTo([ride.customer_id], ride.status, ride);
}

/** en_route / in_progress / completed / cancelled → both participants + admin. */
export function emitRideUpdated(ride) {
  emitTo(
    [`user:${ride.customer_id}`, `user:${ride.driver_id}`, "admin"],
    "ride:updated",
    ride,
  );
  pushTo([ride.customer_id, ride.driver_id], ride.status, ride);
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
