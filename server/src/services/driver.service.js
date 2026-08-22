import { Op } from "sequelize";
import { Driver, User, Ride } from "../models/index.js";
import { haversineKm, etaMinutes } from "../utils/distance.js";

function businessError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

const PROFILE_FIELDS = ["car_model", "plate", "license_no", "price_per_km"];

// ARCHITECTURE §8 nearby rules: online + verified + fresh heartbeat + no
// active ride, then radius/sort/limit. Heartbeat older than 15s = offline.
const FRESH_WINDOW_MS = 15_000;
const NEARBY_RADIUS_KM = 10;
const NEARBY_LIMIT = 20;
const ACTIVE_RIDE_STATUSES = ["requested", "accepted", "en_route", "in_progress"];

function toCard(driver, distanceKm) {
  const round = (n, d = 2) => Number(n.toFixed(d));
  return {
    id: driver.id,
    name: driver.User.name,
    photo: driver.User.photo,
    rating: Number(driver.User.rating),
    car_model: driver.car_model,
    plate: driver.plate,
    price_per_km: Number(driver.price_per_km),
    distance_km: round(distanceKm),
    eta_minutes: etaMinutes(distanceKm),
  };
}

export async function findNearby({ lat, lng }) {
  const candidates = await Driver.findAll({
    where: {
      verified: true,
      online: true,
      updated_at: { [Op.gte]: new Date(Date.now() - FRESH_WINDOW_MS) },
    },
    include: [{ model: User, attributes: ["name", "photo", "rating"] }],
  });

  // A driver is busy while ANY of their rides is active. rides.driver_id
  // references users.id, i.e. Driver.user_id.
  const busyRides = await Ride.findAll({
    attributes: ["driver_id"],
    where: { status: { [Op.in]: ACTIVE_RIDE_STATUSES } },
  });
  const busyUserIds = new Set(busyRides.map((ride) => ride.driver_id));

  return candidates
    .filter((driver) => !busyUserIds.has(driver.user_id))
    .map((driver) => ({
      driver,
      distanceKm: haversineKm(lat, lng, Number(driver.lat), Number(driver.lng)),
    }))
    .filter(({ distanceKm }) => distanceKm <= NEARBY_RADIUS_KM)
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, NEARBY_LIMIT)
    .map(({ driver, distanceKm }) => toCard(driver, distanceKm));
}

/** Task 4.1: create-once vehicle profile (§4 matrix — driver only). */
export async function createProfile(userId, body) {
  const existing = await Driver.findOne({ where: { user_id: userId } });
  if (existing) {
    throw businessError("VALIDATION_ERROR", "Driver profile already exists");
  }

  // verified stays false — only admin verification (§4) flips it.
  return Driver.create({ user_id: userId, ...pickProfileFields(body) });
}

export async function updateOwnProfile(userId, body) {
  const driver = await requireDriver(userId);
  await driver.update(pickProfileFields(body));
  return driver;
}

/** Task 4.6: read own vehicle profile — NOT_FOUND when none yet. */
export async function getOwnProfile(userId) {
  return requireDriver(userId);
}

/**
 * Task 4.1 online toggle — allowed regardless of `verified` (§8 deck filters
 * on verified=1, so an unverified driver never surfaces). updated_at is
 * stamped unconditionally: it is the location heartbeat column (§10) and
 * must refresh even when nothing else changed.
 */
export async function setOnlineStatus(userId, { online, lat, lng }) {
  const driver = await requireDriver(userId);
  driver.online = online;
  if (lat !== undefined) driver.lat = lat;
  if (lng !== undefined) driver.lng = lng;
  driver.updated_at = new Date();
  await driver.save();
  return driver;
}

async function requireDriver(userId) {
  const driver = await Driver.findOne({ where: { user_id: userId } });
  if (!driver) throw businessError("NOT_FOUND", "Driver profile not found");
  return driver;
}

function pickProfileFields(body) {
  const picked = {};
  for (const key of PROFILE_FIELDS) {
    if (body[key] !== undefined) picked[key] = body[key];
  }
  return picked;
}
