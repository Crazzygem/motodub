import { Op } from "sequelize";
import { Driver, Ride, User } from "../models/index.js";
import { sequelize } from "../config/db.js";

// ARCHITECTURE §2 invariant: a ride is "active" from requested → in_progress.
const ACTIVE_RIDE_STATUSES = ["requested", "accepted", "en_route", "in_progress"];

// §2 table as data: who may cancel from where. Admin is the emergency override.
const CANCEL_FROM = {
  admin: ACTIVE_RIDE_STATUSES,
  customer: ["requested", "accepted", "en_route"],
  driver: ["accepted", "en_route"],
};

function businessError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

async function assertNoActiveRide(column, id, code, excludeRideId = null) {
  const where = { [column]: id, status: { [Op.in]: ACTIVE_RIDE_STATUSES } };
  if (excludeRideId !== null) where.id = { [Op.ne]: excludeRideId };
  const active = await Ride.findOne({ where });
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
 * Invariants: one active ride per customer and per driver; the targeted
 * driver must exist, be verified and online.
 */
export async function create(customerId, { driverId, pickup, dropoff }) {
  const driver = await Driver.findByPk(driverId);
  if (!driver) throw businessError("NOT_FOUND", "Driver not found");
  if (!driver.verified || !driver.online) {
    throw businessError(
      "DRIVER_NOT_VERIFIED",
      "Driver is not verified or not online",
    );
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

async function loadOwnRide(rideId, actorId, actorColumn) {
  const ride = await Ride.findByPk(rideId);
  if (!ride) throw businessError("NOT_FOUND", "Ride not found");
  if (ride[actorColumn] !== actorId) {
    throw businessError("FORBIDDEN", "Only the ride's own driver can do that");
  }
  return ride;
}

async function advance(ride, toStatus, fromStatuses, action) {
  if (!fromStatuses.includes(ride.status)) {
    throw businessError(
      "RIDE_INVALID_TRANSITION",
      `Cannot ${action} a ${ride.status} ride`,
    );
  }
  return ride.update({ status: toStatus });
}

/** §2: `requested` → `accepted` (the ride's own driver only). */
export async function accept(driverId, rideId) {
  const ride = await loadOwnRide(rideId, driverId, "driver_id");
  // §2 invariant 1 re-check — the #1 race: two customers swiping one driver.
  // Exclude this very ride or every accept would trip on itself.
  await assertNoActiveRide("driver_id", driverId, "RIDE_BUSY_DRIVER", ride.id);
  return advance(ride, "accepted", ["requested"], "accept");
}

/** §2: `requested` → `declined` (the ride's own driver only). */
export async function decline(driverId, rideId) {
  const ride = await loadOwnRide(rideId, driverId, "driver_id");
  return advance(ride, "declined", ["requested"], "decline");
}

/**
 * §2 cancel rows: customer from requested|accepted|en_route, driver only from
 * accepted|en_route, admin any in_progress-or-earlier (emergency override).
 */
export async function cancel(actorId, actorRole, rideId) {
  const ride = await Ride.findByPk(rideId);
  if (!ride) throw businessError("NOT_FOUND", "Ride not found");

  const isParticipant =
    ride.customer_id === actorId || ride.driver_id === actorId;
  if (actorRole !== "admin" && !isParticipant) {
    throw businessError("FORBIDDEN", "You are not part of this ride");
  }

  const allowedFrom = CANCEL_FROM[actorRole] ?? [];
  return advance(ride, "cancelled", allowedFrom, "cancel");
}

/** §2: `accepted` → `en_route` ("On my way", driver). */
export async function start(driverId, rideId) {
  const ride = await loadOwnRide(rideId, driverId, "driver_id");
  return advance(ride, "en_route", ["accepted"], "start");
}

/** §2: `en_route` → `in_progress` ("Start ride" at pickup, driver). */
export async function startRide(driverId, rideId) {
  const ride = await loadOwnRide(rideId, driverId, "driver_id");
  return advance(ride, "in_progress", ["en_route"], "start");
}

/** §2: `in_progress` → `completed` ("End ride", driver). */
export async function complete(driverId, rideId) {
  const ride = await loadOwnRide(rideId, driverId, "driver_id");
  return advance(ride, "completed", ["in_progress"], "complete");
}

// Which rides column a participant writes, and which column carries the
// rating they RECEIVE (for the users.rating recompute below).
const RATING_SIDES = {
  customer_rating: { raterColumn: "customer_id", receivedColumn: "customer_rating", targetColumn: "driver_id" },
  driver_rating: { raterColumn: "driver_id", receivedColumn: "driver_rating", targetColumn: "customer_id" },
};

async function refreshUserRating(userId, receivedColumn, fkColumn, transaction) {
  const [row] = await Ride.findAll({
    attributes: [[sequelize.fn("AVG", sequelize.col(receivedColumn)), "avg"]],
    where: { [fkColumn]: userId, [receivedColumn]: { [Op.ne]: null } },
    raw: true,
    transaction,
  });
  const avg = parseFloat(row.avg);
  if (Number.isNaN(avg)) return;
  // users.rating is DECIMAL(2,1) — store one decimal.
  await User.update(
    { rating: Math.round(avg * 10) / 10 },
    { where: { id: userId }, transaction },
  );
}

/**
 * §2 invariant 4: ratings only on completed rides, once per participant;
 * customer_rating = what the customer gives the driver, driver_rating the
 * reverse. The TARGET user's average is recomputed from all rated rides.
 */
export async function rate(actorId, rideId, rating) {
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw businessError("VALIDATION_ERROR", "Rating must be an integer from 1 to 5");
  }

  const ride = await Ride.findByPk(rideId);
  if (!ride) throw businessError("NOT_FOUND", "Ride not found");

  const side =
    Object.entries(RATING_SIDES).find(
      ([, s]) => ride[s.raterColumn] === actorId,
    )?.[0] ?? null;
  if (!side) {
    throw businessError("FORBIDDEN", "Only ride participants can rate");
  }
  if (ride.status !== "completed") {
    throw businessError("RIDE_INVALID_TRANSITION", "Only completed rides can be rated");
  }
  if (ride[side] !== null) {
    throw businessError("RIDE_INVALID_TRANSITION", "You already rated this ride");
  }

  const { receivedColumn, targetColumn } = RATING_SIDES[side];
  const targetUserId = ride[targetColumn];

  await sequelize.transaction(async (transaction) => {
    await ride.update({ [side]: rating }, { transaction });
    await refreshUserRating(targetUserId, receivedColumn, targetColumn, transaction);
  });
  return ride.reload();
}

/**
 * §4 GET /api/rides/mine — role-scoped history, newest first. An admin is
 * never a ride participant (the admin feed arrives with Task 6.1), so their
 * scope is empty here by design.
 */
export async function listMine(userId, role) {
  const column =
    role === "customer"
      ? "customer_id"
      : role === "driver"
        ? "driver_id"
        : null;
  if (!column) return [];
  return Ride.findAll({
    where: { [column]: userId },
    order: [
      ["created_at", "DESC"],
      ["id", "DESC"], // tie-break: DATE columns are second-precision
    ],
  });
}

/** §4 GET /api/rides/{id} — visible to participants and admin only. */
export async function getForViewer(viewerId, viewerRole, rideId) {
  const ride = await Ride.findByPk(rideId);
  if (!ride) throw businessError("NOT_FOUND", "Ride not found");

  const isParticipant =
    ride.customer_id === viewerId || ride.driver_id === viewerId;
  if (viewerRole !== "admin" && !isParticipant) {
    throw businessError("FORBIDDEN", "You are not part of this ride");
  }
  return ride;
}
