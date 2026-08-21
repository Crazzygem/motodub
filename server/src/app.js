import express from "express";
import cors from "cors";

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.get("/", (_req, res) => res.redirect("/health"));

  app.get("/health", (_req, res) => {
    res.json({ success: true, data: { status: "ok" } });
  });

  return app;
}
