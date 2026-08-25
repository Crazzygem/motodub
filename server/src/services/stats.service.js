import { Op } from "sequelize";
import { sequelize } from "../config/db.js";
import { Driver, Ride, User } from "../models/index.js";
import { vehiclePhotosOf } from "../utils/vehiclePhotos.js";

function businessError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * Task 6.1 GET /api/admin/stats — KPI snapshot for the dashboard tab.
 * completed_today scopes on updated_at: a ride earns `completed` at the
 * moment it transitions, which is exactly what its updated_at stamps.
 */
export async function getStats() {
  const today = startOfToday();

  const [ridesToday, completedToday, onlineDrivers, requestedNow, ratedRows] =
    await Promise.all([
      Ride.count({ where: { created_at: { [Op.gte]: today } } }),
      Ride.count({ where: { status: "completed", updated_at: { [Op.gte]: today } } }),
      Driver.count({ where: { online: true } }),
      Ride.count({ where: { status: "requested" } }),
      User.findAll({
        attributes: [[sequelize.fn("AVG", sequelize.col("rating")), "avg"]],
        where: { role: "driver" },
        raw: true,
      }),
    ]);

  const avg = parseFloat(ratedRows[0]?.avg);
  return {
    rides_today: ridesToday,
    completed_today: completedToday,
    online_drivers: onlineDrivers,
    avg_rating: Number.isNaN(avg) ? null : Number(avg.toFixed(2)),
    requested_now: requestedNow,
  };
}

/**
 * Task 6.1 GET /api/admin/drivers — every driver with the columns the
 * verification table renders. Wire ids are explicit to kill the classic
 * ambiguity: `driver_id` is the drivers-row PK (what /admin/drivers/:id/*
 * and POST /api/rides driverId address); `user_id` is users.id (what
 * rides.customer_id/driver_id reference).
 */
export async function listDrivers() {
  const drivers = await Driver.findAll({
    include: [{ model: User, attributes: ["name", "email", "phone", "rating", "active"] }],
    order: [["id", "ASC"]],
  });

  return drivers.map(toDriverItem);
}

function toDriverItem(driver) {
  return {
    driver_id: driver.id,
    user_id: driver.user_id,
    name: driver.User.name,
    email: driver.User.email,
    phone: driver.User.phone,
    rating: Number(driver.User.rating),
    active: Boolean(driver.User.active),
    price_per_km: Number(driver.price_per_km),
    // Task 6.3 live map: vehicle identity + last heartbeat position.
    // DECIMAL columns surface as strings — coerce so pins get numbers.
    car_model: driver.car_model,
    plate: driver.plate,
    vehicle_photo: driver.vehicle_photo ?? null,
    vehicle_photos: vehiclePhotosOf(driver),
    lat: driver.lat === null ? null : Number(driver.lat),
    lng: driver.lng === null ? null : Number(driver.lng),
    verified: Boolean(driver.verified),
    online: Boolean(driver.online),
  };
}

async function requireDriverItem(driverRowId) {
  const driver = await Driver.findByPk(driverRowId, {
    include: [{ model: User, attributes: ["name", "email", "phone", "rating", "active"] }],
  });
  if (!driver) throw businessError("NOT_FOUND", "Driver not found");
  return driver;
}

/** Task 6.1 POST /api/admin/drivers/:id/verify — flips drivers.verified. */
export async function verifyDriver(driverRowId) {
  const driver = await requireDriverItem(driverRowId);
  await driver.update({ verified: true });
  return toDriverItem(driver);
}

/**
 * Task 6.1 POST /api/admin/drivers/:id/suspend — deactivation lives on
 * users.active (the account is barred, not the vehicle). RideService refuses
 * new bookings for inactive drivers; driver.service refuses going back
 * online. Unsuspend is out of scope (v1) — seed restores the flag.
 */
export async function suspendDriver(driverRowId) {
  const driver = await requireDriverItem(driverRowId);
  await User.update({ active: false }, { where: { id: driver.user_id } });
  driver.User.active = false;
  return toDriverItem(driver);
}

/**
 * Task 6.1 GET /api/admin/rides — full feed, newest first. Optional ?status=
 * filter validates against the model's own enum — one source of truth, and
 * an unknown value is a client bug (VALIDATION_ERROR), not an empty page.
 */
export async function listRides(status) {
  if (status !== undefined) {
    const valid = Ride.getAttributes().status.values;
    if (!valid.includes(status)) {
      throw businessError(
        "VALIDATION_ERROR",
        `status must be one of: ${valid.join(", ")}`,
      );
    }
  }

  const rides = await Ride.findAll({
    where: status === undefined ? undefined : { status },
    include: [
      { model: User, as: "customer", attributes: ["id", "name", "rating"] },
      { model: User, as: "driver", attributes: ["id", "name", "rating"] },
    ],
    order: [
      ["created_at", "DESC"],
      ["id", "DESC"], // tie-break: DATE columns are second-precision
    ],
  });

  return rides.map((ride) => {
    const json = ride.toJSON();
    // §10 wire names are snake_case — the auto timestamp attributes aren't.
    json.created_at = json.created_at ?? json.createdAt;
    json.updated_at = json.updated_at ?? json.updatedAt;
    delete json.createdAt;
    delete json.updatedAt;
    return json;
  });
}
