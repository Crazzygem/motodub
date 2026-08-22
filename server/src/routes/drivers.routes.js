import { Router } from "express";
import { authorize } from "../middlewares/authorize.js";
import * as driver from "../controllers/driver.controller.js";

const router = Router();

// §4 matrix: GET /api/drivers/nearby → customer only.
router.get("/drivers/nearby", authorize("customer"), driver.nearby);

// §4 matrix: vehicle profile + online toggle → driver only.
router.post("/drivers", authorize("driver"), driver.createProfile);
router.patch("/drivers", authorize("driver"), driver.updateProfile);
router.patch("/drivers/online", authorize("driver"), driver.setOnline);

export default router;
