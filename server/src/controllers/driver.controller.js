import { z } from "zod";
import { ok, fail } from "../utils/envelope.js";
import * as driverService from "../services/driver.service.js";

// Query params arrive as strings — coerce then range-check (§4 envelope).
const nearbySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
});

// Task 4.1 — vehicle profile payloads (§4 matrix, driver only).
const createProfileSchema = z.object({
  car_model: z.string().trim().min(1),
  plate: z.string().trim().min(1),
  license_no: z.string().trim().min(1),
  price_per_km: z.coerce.number().positive(),
});

const updateProfileSchema = createProfileSchema.partial().refine(
  (body) => Object.keys(body).length > 0,
  { message: "At least one field is required" },
);

const onlineSchema = z.object({
  online: z.boolean(),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
});

export async function nearby(req, res) {
  try {
    const parsed = nearbySchema.safeParse(req.query);
    if (!parsed.success) {
      return fail(res, "VALIDATION_ERROR", "lat and lng are required numbers");
    }
    return ok(res, await driverService.findNearby(parsed.data));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

function parseBody(schema, req, res) {
  const parsed = schema.safeParse(req.body ?? {});
  if (!parsed.success) {
    fail(res, "VALIDATION_ERROR", parsed.error.issues[0].message);
    return null;
  }
  return parsed.data;
}

export async function createProfile(req, res) {
  try {
    const body = parseBody(createProfileSchema, req, res);
    if (body === null) return;
    return ok(res, await driverService.createProfile(req.user.id, body), 201);
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function updateProfile(req, res) {
  try {
    const body = parseBody(updateProfileSchema, req, res);
    if (body === null) return;
    return ok(res, await driverService.updateOwnProfile(req.user.id, body));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function setOnline(req, res) {
  try {
    const body = parseBody(onlineSchema, req, res);
    if (body === null) return;
    return ok(res, await driverService.setOnlineStatus(req.user.id, body));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

// Task 4.6 — the driver app's vehicle card reads its own profile; a driver
// with none yet gets NOT_FOUND (the first-time-setup trigger client-side).
export async function me(req, res) {
  try {
    return ok(res, await driverService.getOwnProfile(req.user.id));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

// POST /api/drivers/vehicle-photo — multer already wrote the file; the
// service records its URL and answers the updated driver row.
export async function uploadVehiclePhoto(req, res) {
  try {
    return ok(
      res,
      await driverService.setVehiclePhoto(req.user.id, req.file.filename),
    );
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}
