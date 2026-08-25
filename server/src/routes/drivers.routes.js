import { Router } from "express";
import { authorize } from "../middlewares/authorize.js";
import { imageUpload } from "../middlewares/imageUpload.js";
import * as driver from "../controllers/driver.controller.js";

const router = Router();

// §4 matrix: GET /api/drivers/nearby → customer only.
router.get("/drivers/nearby", authorize("customer"), driver.nearby);

// Vehicle photo upload — same acceptance rules as POST /users/me/avatar,
// multipart field `photo` (jpeg/png/webp ≤ 5MB), driver only.
router.post(
  "/drivers/vehicle-photo",
  authorize("driver"),
  imageUpload("photo"),
  driver.uploadVehiclePhoto,
);

// §4 matrix: vehicle profile + online toggle → driver only.
router.get("/drivers/me", authorize("driver"), driver.me);
router.post("/drivers", authorize("driver"), driver.createProfile);
router.patch("/drivers", authorize("driver"), driver.updateProfile);
router.patch("/drivers/online", authorize("driver"), driver.setOnline);

export default router;
