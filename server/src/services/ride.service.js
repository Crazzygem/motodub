import { Op } from "sequelize";
import { Driver, Ride, User } from "../models/index.js";
import { sequelize } from "../config/db.js";
import { notifyRide } from "../realtime/events.js";

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

  // Task 6.1 invariant: a suspended (users.active=false) driver is
  // unbookable — admin action bars the account, not just the deck card.
  const driverUser = await User.findByPk(driver.user_id, {
    attributes: ["id", "active"],
  });
  if (!driverUser || !driverUser.active) {
    throw businessError("FORBIDDEN", "Driver is suspended");
  }

  // One active ride per customer, one per driver (§2 invariants 1–2).
  await assertNoActiveRide("customer_id", customerId, "RIDE_BUSY_CUSTOMER");

  // rides.driver_id references users.id, i.e. Driver.user_id.
  await assertNoActiveRide("driver_id", driver.user_id, "RIDE_BUSY_DRIVER");

  const ride = await Ride.create({
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
  // §6: the socket only announces — REST already committed the row.
  notifyRide(ride);
  return ride;
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
  const updated = await ride.update({ status: toStatus });
  // Every §2 transition funnels through here — one hook announces them all.
  notifyRide(updated);
  return updated;
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
 *
 * Task 5.2: each row carries timestamps plus the opposite-party snapshot —
 * driver view → customer name/rating · customer view → driver name/rating
 * and car/plate (which live on `drivers`, keyed by user_id, not on users).
 */
export async function listMine(userId, role) {
  const column =
    role === "customer"
      ? "customer_id"
      : role === "driver"
        ? "driver_id"
        : null;
  if (!column) return [];

  const rides = await Ride.findAll({
    where: { [column]: userId },
    include: [
      { model: User, as: "customer", attributes: ["id", "name", "rating"] },
      { model: User, as: "driver", attributes: ["id", "name", "rating"] },
    ],
    order: [
      ["created_at", "DESC"],
      ["id", "DESC"], // tie-break: DATE columns are second-precision
    ],
  });

  // One vehicle query per distinct driver — never per ride.
  const vehicles = await Driver.findAll({
    where: {
      user_id: [...new Set(rides.map((ride) => ride.driver_id))],
    },
    attributes: ["user_id", "car_model", "plate"],
  });
  const vehicleByUserId = new Map(vehicles.map((v) => [v.user_id, v]));

  return rides.map((ride) => {
    const json = ride.toJSON();

    // §10 wire names are snake_case — the auto timestamp attributes aren't.
    json.created_at = json.created_at ?? json.createdAt;
    json.updated_at = json.updated_at ?? json.updatedAt;
    delete json.createdAt;
    delete json.updatedAt;

    if (json.driver) {
      const vehicle = vehicleByUserId.get(ride.driver_id);
      json.driver.car_model = vehicle?.car_model ?? null;
      json.driver.plate = vehicle?.plate ?? null;
    }
    return json;
  });
}

/**
 * §4 GET /api/rides/{id} — visible to participants and admin only. The ride
 * row carries a `customer` name/rating snapshot (Task 4.6 request card) and
 * a `driver` snapshot with phone + car/plate for the tracking screen's
 * driver card (Task 5.1); the socket payload stays id-only per §6 — REST is
 * the source of truth.
 */
export async function getForViewer(viewerId, viewerRole, rideId) {
  const ride = await Ride.findByPk(rideId, {
    include: [
      { model: User, as: "customer", attributes: ["id", "name", "rating"] },
      { model: User, as: "driver", attributes: ["id", "name", "phone", "photo", "rating"] },
    ],
  });
  if (!ride) throw businessError("NOT_FOUND", "Ride not found");

  const isParticipant =
    ride.customer_id === viewerId || ride.driver_id === viewerId;
  if (viewerRole !== "admin" && !isParticipant) {
    throw businessError("FORBIDDEN", "You are not part of this ride");
  }

  // car_model/plate/vehicle_photo live on drivers (keyed by user_id), not users.
  const vehicle = await Driver.findOne({
    where: { user_id: ride.driver_id },
    attributes: ["car_model", "plate", "vehicle_photo"],
  });

  return {
    ...ride.toJSON(),
    driver: {
      ...ride.driver?.toJSON(),
      car_model: vehicle?.car_model ?? null,
      plate: vehicle?.plate ?? null,
      vehicle_photo: vehicle?.vehicle_photo ?? null,
    },
  };
}
