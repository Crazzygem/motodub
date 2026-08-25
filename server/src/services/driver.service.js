import path from "node:path";
import fsp from "node:fs/promises";
import { Op } from "sequelize";
import { Driver, User, Ride } from "../models/index.js";
import { haversineKm, etaMinutes } from "../utils/distance.js";
import { vehiclePhotosOf } from "../utils/vehiclePhotos.js";
import { UPLOADS_DIR } from "../config/uploads.js";

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
    vehicle_photo: driver.vehicle_photo ?? null,
    vehicle_photos: vehiclePhotosOf(driver),
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
 * POST /api/drivers/vehicle-photo — multer already wrote the file; record
 * its URL on drivers.vehicle_photo and answer the updated row. The cover
 * stays canonical here: it replaces the cover AND resets the gallery to
 * exactly that photo.
 */
export async function setVehiclePhoto(userId, filename) {
  const driver = await requireDriver(userId);
  const url = `/uploads/${filename}`;
  await driver.update({ vehicle_photo: url, vehicle_photos: [url] });
  return driver;
}

// Tinder-style multi-photo card: the deck hero cycles through up to six
// vehicle photos; drivers.vehicle_photo stays the cover (first element).
const MAX_VEHICLE_PHOTOS = 6;

/** Gallery rows as an array, falling back to the legacy single cover. */
function galleryOf(driver) {
  const photos = driver.vehicle_photos;
  if (Array.isArray(photos)) return [...photos];
  const legacy = driver.vehicle_photo;
  return typeof legacy === "string" && legacy.length > 0 ? [legacy] : [];
}

/**
 * POST /api/drivers/photos — multer already wrote every file; APPEND their
 * URLs to the gallery, capping at MAX_VEHICLE_PHOTOS total, and keep the
 * cover synced to the first element.
 */
export async function addVehiclePhotos(userId, filenames) {
  if (!Array.isArray(filenames) || filenames.length === 0) {
    throw businessError("VALIDATION_ERROR", "At least one photo is required");
  }
  const driver = await requireDriver(userId);
  const current = galleryOf(driver);
  if (current.length + filenames.length > MAX_VEHICLE_PHOTOS) {
    throw businessError(
      "VALIDATION_ERROR",
      `Up to ${MAX_VEHICLE_PHOTOS} vehicle photos are allowed`,
    );
  }
  const photos = [...current, ...filenames.map((f) => `/uploads/${f}`)];
  await driver.update({ vehicle_photos: photos, vehicle_photo: photos[0] });
  return driver;
}

/**
 * DELETE /api/drivers/photos — drop the gallery photo at [index], unlink its
 * file best-effort, re-sync the cover (first element; null when empty).
 * VALIDATION_ERROR when the index is out of range.
 */
export async function removeVehiclePhoto(userId, index) {
  const driver = await requireDriver(userId);
  const photos = galleryOf(driver);
  if (!Number.isInteger(index) || index < 0 || index >= photos.length) {
    throw businessError("VALIDATION_ERROR", "Photo index out of range");
  }
  const [removed] = photos.splice(index, 1);
  await driver.update({
    vehicle_photos: photos,
    vehicle_photo: photos[0] ?? null,
  });
  await unlinkUploadBestEffort(removed);
  return driver;
}

/** Remove a stored /uploads file; a missing or odd URL never fails the API. */
async function unlinkUploadBestEffort(url) {
  if (typeof url !== "string" || !url.startsWith("/uploads/")) return;
  try {
    // basename only — stored URLs must never escape UPLOADS_DIR.
    await fsp.rm(path.join(UPLOADS_DIR, path.basename(url)));
  } catch {
    // best-effort by design
  }
}

/**
 * Task 4.1 online toggle — allowed regardless of `verified` (§8 deck filters
 * on verified=1, so an unverified driver never surfaces). updated_at is
 * stamped unconditionally: it is the location heartbeat column (§10) and
 * must refresh even when nothing else changed.
 */
export async function setOnlineStatus(userId, { online, lat, lng }) {
  const driver = await requireDriver(userId);

  // Task 6.1: a suspended driver cannot go back online (going offline stays
  // allowed, so an already-online driver can still be switched off cleanly).
  if (online) {
    const user = await User.findByPk(userId, { attributes: ["id", "active"] });
    if (!user || !user.active) {
      throw businessError("FORBIDDEN", "Driver is suspended");
    }
  }

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
