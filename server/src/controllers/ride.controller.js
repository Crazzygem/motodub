import { z } from "zod";
import { ok, fail } from "../utils/envelope.js";
import * as rideService from "../services/ride.service.js";

// §4 contract body: {driverId, pickup{lat,lng,address}, dropoff{lat,lng,address}}
const placeSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  address: z.string().trim().min(1),
});

const createSchema = z.object({
  driverId: z.coerce.number().int().positive(),
  pickup: placeSchema,
  dropoff: placeSchema,
});

// §2 rate trigger body; the 1–5 rule is restated in the service.
const rateSchema = z.object({
  stars: z.coerce.number().int().min(1).max(5),
});

const idParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

function parseId(req, res) {
  const parsed = idParamSchema.safeParse(req.params);
  if (!parsed.success) {
    fail(res, "VALIDATION_ERROR", "Ride id must be a positive integer");
    return null;
  }
  return parsed.data.id;
}

async function respond(res, fn) {
  try {
    return ok(res, await fn());
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function create(req, res) {
  try {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) {
      return fail(res, "VALIDATION_ERROR", "driverId, pickup and dropoff are required");
    }
    return ok(res, await rideService.create(req.user.id, parsed.data), 201);
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function accept(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  return respond(res, () => rideService.accept(req.user.id, id));
}

export async function decline(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  return respond(res, () => rideService.decline(req.user.id, id));
}

export async function cancel(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  // §4 matrix: customer/driver own-ride + admin emergency — actor rules live
  // in RideService.cancel(actorId, actorRole, rideId).
  return respond(res, () => rideService.cancel(req.user.id, req.user.role, id));
}

export async function start(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  return respond(res, () => rideService.start(req.user.id, id));
}

export async function startRide(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  return respond(res, () => rideService.startRide(req.user.id, id));
}

export async function complete(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  return respond(res, () => rideService.complete(req.user.id, id));
}

export async function rate(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  const parsed = rateSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    return fail(res, "VALIDATION_ERROR", "stars must be an integer from 1 to 5");
  }
  return respond(res, () => rideService.rate(req.user.id, id, parsed.data.stars));
}

export async function mine(req, res) {
  return respond(res, () => rideService.listMine(req.user.id, req.user.role));
}

export async function show(req, res) {
  const id = parseId(req, res);
  if (id === null) return undefined;
  return respond(res, () =>
    rideService.getForViewer(req.user.id, req.user.role, id),
  );
}
