import { z } from "zod";
import { ok, fail } from "../utils/envelope.js";
import * as driverService from "../services/driver.service.js";

// Query params arrive as strings — coerce then range-check (§4 envelope).
const nearbySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
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
