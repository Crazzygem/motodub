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
