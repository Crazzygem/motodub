import { Op } from "sequelize";
import { Driver, User, Ride } from "../models/index.js";
import { haversineKm, etaMinutes } from "../utils/distance.js";

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
