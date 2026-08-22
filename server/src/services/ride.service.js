import { Op } from "sequelize";
import { Driver, Ride } from "../models/index.js";

// ARCHITECTURE §2 invariant: a ride is "active" from requested → in_progress.
const ACTIVE_RIDE_STATUSES = ["requested", "accepted", "en_route", "in_progress"];

function businessError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

async function assertNoActiveRide(column, id, code) {
  const active = await Ride.findOne({
    where: { [column]: id, status: { [Op.in]: ACTIVE_RIDE_STATUSES } },
  });
  if (active) {
    throw businessError(
      code,
      code === "RIDE_BUSY_CUSTOMER"
        ? "You already have an active ride"
        : "Driver already has an active ride",
    );
  }
}

/**
 * ARCHITECTURE §2 transition `(new) → requested` (customer actor).
 * Task 3.5 minimal create — the full state machine lands in Phase 4.2;
 * every later call goes through the same service interface.
 */
export async function create(customerId, { driverId, pickup, dropoff }) {
  const driver = await Driver.findByPk(driverId);
  if (!driver) throw businessError("NOT_FOUND", "Driver not found");
  if (!driver.verified) {
    throw businessError("DRIVER_NOT_VERIFIED", "Driver is not verified yet");
  }

  // One active ride per customer, one per driver (§2 invariants 1–2).
  await assertNoActiveRide("customer_id", customerId, "RIDE_BUSY_CUSTOMER");

  // rides.driver_id references users.id, i.e. Driver.user_id.
  await assertNoActiveRide("driver_id", driver.user_id, "RIDE_BUSY_DRIVER");

  return Ride.create({
    customer_id: customerId,
    driver_id: driver.user_id,
    status: "requested",
    pickup_lat: pickup.lat,
    pickup_lng: pickup.lng,
    pickup_address: pickup.address,
    dropoff_lat: dropoff.lat,
    dropoff_lng: dropoff.lng,
    dropoff_address: dropoff.address,
    // fare is reserved and NEVER set (§6/§9).
  });
}
