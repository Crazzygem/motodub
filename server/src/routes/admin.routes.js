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
// Seth directive: admin edits ANY driver (bots included) like the driver side.
router.patch("/admin/drivers/:id", authorize("admin"), admin.updateDriver);
router.get("/admin/rides", authorize("admin"), admin.rides);

// Server-side bots manager — default OFF, started/stopped on demand. The
// embedded manager speaks REST+Socket.IO loopback to this same server.
router.post("/admin/bots", authorize("admin"), admin.botsStart);
router.delete("/admin/bots", authorize("admin"), admin.botsStop);
router.get("/admin/bots/status", authorize("admin"), admin.botsStatus);

export default router;
