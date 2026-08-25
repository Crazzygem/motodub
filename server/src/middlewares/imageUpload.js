import crypto from "node:crypto";
import multer from "multer";
import { fail } from "../utils/envelope.js";
import { UPLOADS_DIR } from "../config/uploads.js";

// Shared by POST /api/users/me/avatar, POST /api/drivers/vehicle-photo and
// POST /api/drivers/photos: uuid filename, extension derived from the
// whitelisted mimetype only (never from the client's original name), 5MB cap.
const IMAGE_EXTENSIONS = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
};

function makeMulter() {
  return multer({
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
  });
}

function runMultipart(upload, req, res, next) {
  upload(req, res, (err) => {
    if (!err) return next();
    // Every rejection mode (wrong type / >5MB / too many files) surfaces as
    // VALIDATION_ERROR.
    return fail(res, "VALIDATION_ERROR", err.message);
  });
}

/** Multipart single-file handler for [field]; rejections answer VALIDATION_ERROR. */
export function imageUpload(field) {
  return (req, res, next) =>
    runMultipart(makeMulter().single(field), req, res, next);
}

/**
 * Multipart multi-file handler — up to [maxCount] files under [field]
 * (POST /api/drivers/photos gallery uploads).
 */
export function imagesUpload(field, maxCount) {
  return (req, res, next) =>
    runMultipart(makeMulter().array(field, maxCount), req, res, next);
}
