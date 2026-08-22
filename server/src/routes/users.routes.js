import { Router } from "express";
import { z } from "zod";
import { validate } from "../middlewares/validate.js";
import * as users from "../controllers/users.controller.js";

const router = Router();

// §4 matrix: every authenticated role registers its own device token.
const fcmTokenSchema = z.object({
  token: z.string().trim().min(1),
});

router.post(
  "/users/fcm-token",
  validate(fcmTokenSchema),
  users.saveFcmToken,
);

export default router;
