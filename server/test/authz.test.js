import { describe, expect, it } from "@jest/globals";
import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";
import { authenticate } from "../src/middlewares/authenticate.js";
import { authorize } from "../src/middlewares/authorize.js";
import { errorHandler } from "../src/middlewares/errorHandler.js";
import { ok } from "../src/utils/envelope.js";
import { signToken } from "../src/utils/jwt.js";
import { env } from "../src/config/env.js";
import { User } from "../src/models/user.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";
import { afterAll } from "@jest/globals";

afterAll(() => sequelize.close());

// Probe app wired with the real middlewares (no role-gated routes exist in
// app.js yet — they arrive with rides/drivers endpoints).
function probeApp() {
  const app = express();
  app.use(express.json());
  app.get("/driver-only", authenticate, authorize("driver"), (_req, res) =>
    ok(res, { user: _req.user }),
  );
  app.get("/boom", authenticate, () => {
    throw new Error("boom");
  });
  app.get("/coded", authenticate, () => {
    const err = new Error("No such thing");
    err.code = "NOT_FOUND";
    throw err;
  });
  app.use(errorHandler);
  return app;
}

describe("authenticate", () => {
  it("rejects a missing token with 401 UNAUTHORIZED", async () => {
    const res = await request(probeApp()).get("/driver-only");

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("rejects an invalid token with 401 UNAUTHORIZED", async () => {
    const res = await request(probeApp())
      .get("/driver-only")
      .set("Authorization", "Bearer not-a-jwt");

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("accepts a valid token and attaches req.user", async () => {
    const token = signToken({ id: 7, role: "driver" });
    const res = await request(probeApp())
      .get("/driver-only")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user).toEqual({ id: 7, role: "driver" });
  });
});

describe("authorize", () => {
  it("blocks a customer from a driver route with 403 FORBIDDEN", async () => {
    const token = signToken({ id: 1, role: "customer" });
    const res = await request(probeApp())
      .get("/driver-only")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("allows the listed role through", async () => {
    const token = signToken({ id: 2, role: "driver" });
    const res = await request(probeApp())
      .get("/driver-only")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(200);
  });
});

describe("errorHandler", () => {
  it("maps unknown errors to 500 INTERNAL", async () => {
    const res = await request(probeApp())
      .get("/boom")
      .set("Authorization", `Bearer ${signToken({ id: 1, role: "customer" })}`);

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe("INTERNAL");
    expect(res.body.error.message).toBe("Internal server error");
  });

  it("keeps code + message for coded errors", async () => {
    const res = await request(probeApp())
      .get("/coded")
      .set("Authorization", `Bearer ${signToken({ id: 1, role: "customer" })}`);

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
    expect(res.body.error.message).toBe("No such thing");
  });
});

describe("wired app (createApp)", () => {
  it("protects /api beyond the public auth routes", async () => {
    const res = await request(createApp()).post("/api/rides").send({});

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("accepts a real register-issued JWT on a protected path", async () => {
    const app = createApp();
    const email = `${Date.now()}-authz@authtest.demo`;
    const reg = await request(app).post("/api/register").send({
      name: "Authz Probe",
      phone: "012345678",
      email,
      password: "Password1",
    });
    expect(reg.status).toBe(201);

    const payload = jwt.verify(reg.body.data.token, env.JWT_SECRET);
    expect(payload.role).toBe("customer");
    expect(typeof payload.sub).toBe("number");

    // customer passes authenticate on any /api path past the public routes
    const probe = await request(app)
      .get("/api/anything-unmapped")
      .set("Authorization", `Bearer ${reg.body.data.token}`);
    expect(probe.status).not.toBe(401);

    await User.destroy({ where: { email } });
  });
});
