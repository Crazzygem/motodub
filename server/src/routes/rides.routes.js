import { Router } from "express";
import { authorize } from "../middlewares/authorize.js";
import * as ride from "../controllers/ride.controller.js";

const router = Router();

// §4 role access matrix. Driver actions are driver-gated here; the
// "own ride only" rule is re-checked inside RideService. cancel/rate stay
// authenticated-only at the gate — their actor rules live in the service.
router.post("/rides", authorize("customer"), ride.create);
router.post("/rides/:id/accept", authorize("driver"), ride.accept);
router.post("/rides/:id/decline", authorize("driver"), ride.decline);
router.post("/rides/:id/start", authorize("driver"), ride.start);
router.post("/rides/:id/start-ride", authorize("driver"), ride.startRide);
router.post("/rides/:id/complete", authorize("driver"), ride.complete);
router.post("/rides/:id/cancel", ride.cancel);
router.post("/rides/:id/rate", ride.rate);

// Literal paths must register before /rides/:id so "mine" isn't parsed as an id.
router.get("/rides/mine", ride.mine);
router.get("/rides/:id", ride.show);

export default router;
