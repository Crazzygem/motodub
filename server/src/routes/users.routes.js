import { Router } from "express";
import { z } from "zod";
import { validate } from "../middlewares/validate.js";
import { imageUpload } from "../middlewares/imageUpload.js";
import * as users from "../controllers/users.controller.js";

const router = Router();

// §4 matrix: every authenticated role registers its own device token.
const fcmTokenSchema = z.object({
  token: z.string().trim().min(1),
});

// PATCH /api/users/me — own-row edit. Unknown keys (email, role, rating…)
// are stripped, so email is immutable by construction.
const updateProfileSchema = z
  .object({
    name: z.string().trim().min(2).max(80).optional(),
    phone: z.string().trim().regex(/^[0-9+][0-9\s-]{4,19}$/).optional(), // Khmer-ish, 5-20 chars
  })
  .refine((v) => Object.keys(v).length > 0, {
    message: "At least one field (name or phone) is required",
  });

const changePasswordSchema = z.object({
  current_password: z.string().min(1),
  new_password: z.string().min(8).max(72), // bcrypt-safe length cap
});

// POST /api/users/me/avatar — uuid filename, extension derived from the
// whitelisted mimetype only (never from the client's original name).
const handleAvatarUpload = imageUpload("avatar");

router.post(
  "/users/fcm-token",
  validate(fcmTokenSchema),
  users.saveFcmToken,
);

router.patch("/users/me", validate(updateProfileSchema), users.updateMe);
router.post("/users/me/avatar", handleAvatarUpload, users.uploadAvatar);
router.post(
  "/users/me/password",
  validate(changePasswordSchema),
  users.changeMyPassword,
);

export default router;
