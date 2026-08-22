import { Router } from "express";
import { authorize } from "../middlewares/authorize.js";
import * as ride from "../controllers/ride.controller.js";

const router = Router();

// §4 matrix: POST /api/rides → customer only. Phase 4.3 adds the
// accept/decline/start/…/rate triggers behind the same service.
router.post("/rides", authorize("customer"), ride.create);

export default router;
