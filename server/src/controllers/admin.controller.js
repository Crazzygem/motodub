import { z } from "zod";
import { ok, fail } from "../utils/envelope.js";
import * as statsService from "../services/stats.service.js";

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
