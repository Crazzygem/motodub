import crypto from "node:crypto";
import multer from "multer";
import { fail } from "../utils/envelope.js";
import { UPLOADS_DIR } from "../config/uploads.js";

// Shared by POST /api/users/me/avatar and POST /api/drivers/vehicle-photo:
// uuid filename, extension derived from the whitelisted mimetype only
// (never from the client's original name), 5MB cap.
const IMAGE_EXTENSIONS = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
};

/** Multipart single-file handler for [field]; rejections answer VALIDATION_ERROR. */
export function imageUpload(field) {
  const upload = multer({
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
  }).single(field);

  return (req, res, next) => {
    upload(req, res, (err) => {
      if (!err) return next();
      // Both rejection modes (wrong type / >5MB) surface as VALIDATION_ERROR.
      return fail(res, "VALIDATION_ERROR", err.message);
    });
  };
}
