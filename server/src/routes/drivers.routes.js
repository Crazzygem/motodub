import { Router } from "express";
import { authorize } from "../middlewares/authorize.js";
import * as driver from "../controllers/driver.controller.js";

const router = Router();

// §4 matrix: GET /api/drivers/nearby → customer only.
router.get("/drivers/nearby", authorize("customer"), driver.nearby);

export default router;
