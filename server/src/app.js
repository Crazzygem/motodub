import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth.routes.js";
import driverRoutes from "./routes/drivers.routes.js";
import rideRoutes from "./routes/rides.routes.js";
import usersRoutes from "./routes/users.routes.js";
import { authenticate } from "./middlewares/authenticate.js";
import { errorHandler } from "./middlewares/errorHandler.js";

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.use("/api", authRoutes);
  // Public auth routes live above; everything else under /api requires a
  // valid token (ARCHITECTURE §4 — secure by default).
  app.use("/api", authenticate);
  app.use("/api", driverRoutes);
  app.use("/api", rideRoutes);
  app.use("/api", usersRoutes);

  app.get("/", (_req, res) => res.redirect("/health"));

  app.get("/health", (_req, res) => {
    res.json({ success: true, data: { status: "ok" } });
  });

  app.use(errorHandler);

  return app;
}
