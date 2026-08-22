import { Router } from "express";
import { authorize } from "../middlewares/authorize.js";
import * as admin from "../controllers/admin.controller.js";

const router = Router();

// §4 role access matrix — the whole admin block is admin-only. :id below is
// the drivers-row PK (the same id POST /api/rides carries as driverId).
router.get("/admin/stats", authorize("admin"), admin.stats);
router.get("/admin/drivers", authorize("admin"), admin.drivers);
router.post("/admin/drivers/:id/verify", authorize("admin"), admin.verify);
router.post("/admin/drivers/:id/suspend", authorize("admin"), admin.suspend);
router.get("/admin/rides", authorize("admin"), admin.rides);

export default router;
