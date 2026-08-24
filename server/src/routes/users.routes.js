import path from "node:path";
import crypto from "node:crypto";
import { Router } from "express";
import { z } from "zod";
import multer from "multer";
import { validate } from "../middlewares/validate.js";
import { fail } from "../utils/envelope.js";
import { UPLOADS_DIR } from "../config/uploads.js";
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
const IMAGE_EXTENSIONS = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
};

const avatarUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
    filename: (_req, file, cb) =>
      cb(null, `${crypto.randomUUID()}${IMAGE_EXTENSIONS[file.mimetype]}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!IMAGE_EXTENSIONS[file.mimetype]) {
      return cb(new Error("Only jpeg, png or webp images are allowed"));
    }
    return cb(null, true);
  },
}).single("avatar");

function handleAvatarUpload(req, res, next) {
  avatarUpload(req, res, (err) => {
    if (!err) return next();
    // Both rejection modes (wrong type / >5MB) surface as VALIDATION_ERROR.
    return fail(res, "VALIDATION_ERROR", err.message);
  });
}

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
