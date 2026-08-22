import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth.routes.js";

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.use("/api", authRoutes);

  app.get("/", (_req, res) => res.redirect("/health"));

  app.get("/health", (_req, res) => {
    res.json({ success: true, data: { status: "ok" } });
  });

  return app;
}
