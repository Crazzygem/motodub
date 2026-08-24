import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth.routes.js";
import driverRoutes from "./routes/drivers.routes.js";
import rideRoutes from "./routes/rides.routes.js";
import usersRoutes from "./routes/users.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import { authenticate } from "./middlewares/authenticate.js";
import { errorHandler } from "./middlewares/errorHandler.js";
import { ensureUploadsDir, UPLOADS_DIR } from "./config/uploads.js";

export function createApp() {
  const app = express();

  ensureUploadsDir(); // avatar storage target exists before any upload

  app.use(cors());
  app.use(express.json());

  // Avatars are public read-only assets; served outside the /api auth gate.
  app.use("/uploads", express.static(UPLOADS_DIR));

  app.use("/api", authRoutes);
  // Public auth routes live above; everything else under /api requires a
  // valid token (ARCHITECTURE §4 — secure by default).
  app.use("/api", authenticate);
  app.use("/api", driverRoutes);
  app.use("/api", rideRoutes);
  app.use("/api", usersRoutes);
  app.use("/api", adminRoutes);

  app.get("/", (_req, res) => res.redirect("/health"));

  app.get("/health", (_req, res) => {
    res.json({ success: true, data: { status: "ok" } });
  });

  app.use(errorHandler);

  return app;
}
