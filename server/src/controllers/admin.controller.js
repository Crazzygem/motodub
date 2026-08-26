import { z } from "zod";
import { ok, fail } from "../utils/envelope.js";
import * as statsService from "../services/stats.service.js";
import {
  startEmbeddedBots,
  stopEmbeddedBots,
  embeddedBotsStatus,
} from "../bots/bot_manager.js";

// Same :id convention as rides (positive integer), but here it addresses the
// drivers-row PK — see stats.service.listDrivers for the id semantics.
const idParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function stats(req, res) {
  try {
    return ok(res, await statsService.getStats());
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function drivers(req, res) {
  try {
    return ok(res, await statsService.listDrivers());
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

// Not async on purpose (ride.controller.parseId convention): a returned
// Promise would slip past the `=== null` guard and reach the service.
function parseDriverId(req, res) {
  const parsed = idParamSchema.safeParse(req.params);
  if (!parsed.success) {
    fail(res, "VALIDATION_ERROR", "Driver id must be a positive integer");
    return null;
  }
  return parsed.data.id;
}

export async function verify(req, res) {
  const id = parseDriverId(req, res);
  if (id === null) return undefined;

  try {
    return ok(res, await statsService.verifyDriver(id));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function suspend(req, res) {
  const id = parseDriverId(req, res);
  if (id === null) return undefined;

  try {
    return ok(res, await statsService.suspendDriver(id));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function rides(req, res) {
  try {
    // §4 GET /api/admin/rides?status=… — unknown values are rejected by the
    // service against the model enum (VALIDATION_ERROR).
    return ok(res, await statsService.listRides(req.query.status));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

// ---------------------------------------------------------------------------
// Seth directive — server-side bots manager + admin driver edit.
// ---------------------------------------------------------------------------

// POST /api/admin/bots {count?:1|2|3=2} — bot customer/driver pairs to deploy.
const botsStartSchema = z.object({
  count: z.coerce.number().int().min(1).max(3).default(2),
});

// Same rules as the driver's own PATCH (vehicle fields) and PATCH /users/me
// (name/phone). Unknown keys are stripped, so email stays immutable and an
// all-unknown payload fails the refine like an empty one.
const updateDriverSchema = z
  .object({
    name: z.string().trim().min(2).max(80).optional(),
    phone: z.string().trim().regex(/^[0-9+][0-9\s-]{4,19}$/).optional(),
    car_model: z.string().trim().min(1).optional(),
    plate: z.string().trim().min(1).optional(),
    license_no: z.string().trim().min(1).optional(),
    price_per_km: z.coerce.number().positive().optional(),
  })
  .refine((body) => Object.keys(body).length > 0, {
    message: "At least one field is required",
  });

// Wire shape for the bots endpoints — camelCase per this contract's spec,
// with live verified/online/photos enriched from the drivers/users rows.
async function botsWire(status) {
  return {
    running: status.running,
    drivers: await statsService.listBotDrivers(status.emails),
    ridesSpawned: status.ridesSpawned,
    uptimeSec: status.uptimeSec,
    lastRideAt: status.lastRideAt,
  };
}

export async function botsStart(req, res) {
  try {
    const parsed = botsStartSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return fail(res, "VALIDATION_ERROR", "count must be 1, 2 or 3");
    }
    let status;
    try {
      status = await startEmbeddedBots(parsed.data);
    } catch (err) {
      if (err.code !== "BOT_ALREADY_RUNNING") throw err;
      // Documented idempotency choice: an explicit conflict beats a silent
      // success pretending to be a fresh start.
      return fail(res, "BOT_ALREADY_RUNNING", "Bots manager is already running");
    }
    return ok(res, await botsWire(status));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function botsStop(req, res) {
  try {
    await stopEmbeddedBots(); // offlines drivers + closes sockets; no-op when off
    return ok(res, { running: false });
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function botsStatus(req, res) {
  try {
    return ok(res, await botsWire(embeddedBotsStatus()));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function updateDriver(req, res) {
  const parsed = idParamSchema.safeParse(req.params);
  if (!parsed.success) {
    return fail(res, "VALIDATION_ERROR", "Driver id must be a positive integer");
  }

  try {
    const body = updateDriverSchema.safeParse(req.body ?? {});
    if (!body.success) {
      return fail(res, "VALIDATION_ERROR", body.error.issues[0].message);
    }
    return ok(res, await statsService.updateDriver(parsed.data.id, body.data));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}
