import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const UPLOADS_DIR = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "uploads",
);

// Boot-time safety net: avatars land here, and the directory is gitignored.
export function ensureUploadsDir() {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}
