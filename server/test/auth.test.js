import { afterAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { User } from "../src/models/user.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

const app = createApp();
const domain = "authtest.demo";

let email;

function newUser(overrides = {}) {
  return {
    name: "Test User",
    phone: "012345678",
    email,
    password: "Password1",
    ...overrides,
  };
}

beforeAll(async () => {
  await sequelize.authenticate();
  // unique per run so the suite can run repeatedly against the same DB
  email = `${Date.now()}-${Math.floor(Math.random() * 10000)}@${domain}`;
});

afterAll(async () => {
  await User.destroy({ where: { email } });
  await sequelize.close();
});

describe("POST /api/register", () => {
  it("creates a user and returns the ok envelope with token + user", async () => {
    const res = await request(app).post("/api/register").send(newUser());

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(typeof res.body.data.token).toBe("string");
    expect(res.body.data.user.email).toBe(email);
    expect(res.body.data.user.role).toBe("customer");
    expect(res.body.data.user.password_hash).toBeUndefined();
  });

  it("rejects a duplicate email with VALIDATION_ERROR", async () => {
    const res = await request(app).post("/api/register").send(newUser());

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects a too-short password with VALIDATION_ERROR", async () => {
    const res = await request(app)
      .post("/api/register")
      .send(newUser({ password: "short" }));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});

describe("POST /api/login", () => {
  it("returns token + user for correct credentials", async () => {
    const res = await request(app)
      .post("/api/login")
      .send({ email, password: "Password1" });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(typeof res.body.data.token).toBe("string");
    expect(res.body.data.user.email).toBe(email);
  });

  it("rejects a wrong password with UNAUTHORIZED", async () => {
    const res = await request(app)
      .post("/api/login")
      .send({ email, password: "WrongPass1" });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });
});
