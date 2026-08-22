import { execSync } from "node:child_process";
import http from "node:http";
import { afterAll, beforeAll, describe, expect, it, jest } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";

// Task 4.7 (server slice) — FCM token registration + push no-op safety
// (ARCHITECTURE §7).
//
// Isolation: motodub_test like socket-events.test.js, with DEDICATED
// [fcm-test] actors registered below — this suite parks an active ride
// mid-test. DB_NAME must be set BEFORE the dynamic imports resolve
// config/db.js.
const ORIGINAL_DB_NAME = process.env.DB_NAME;
process.env.DB_NAME = "motodub_test";

const MARKER = "[fcm-test]";
const CUSTOMER_EMAIL = "fcm-cust@taxi.demo";
const DRIVER_EMAIL = "fcm-driver@taxi.demo";

let sequelize;
let User;
let Driver;
let app;
let server;

const customer = { token: null, id: null };
const driver = { token: null, id: null, driverRowId: null };

function bookingBody(driverRowId, tag) {
  return {
    driverId: driverRowId,
    pickup: {
      lat: 11.5564,
      lng: 104.9282,
      address: `${MARKER} pickup ${tag}`,
    },
    dropoff: {
      lat: 11.5449,
      lng: 104.8922,
      address: `${MARKER} dropoff ${tag}`,
    },
  };
}

async function login(email) {
  const res = await request(app)
    .post("/api/login")
    .send({ email, password: "Demo@1234" });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

async function register(name, email, role) {
  const res = await request(app).post("/api/register").send({
    name,
    phone: "+855 900 111",
    email,
    password: "Demo@1234",
    role,
  });
  expect(res.status).toBe(201);
}

function authed(token) {
  return {
    post: (url, body) =>
      request(app).post(url).set("Authorization", `Bearer ${token}`).send(body),
    patch: (url, body) =>
      request(app).patch(url).set("Authorization", `Bearer ${token}`).send(body),
  };
}

beforeAll(async () => {
  await import("dotenv/config");

  // Self-bootstrapping test setup (same as ride-flow.test.js).
  const mysql = (await import("mysql2/promise")).default;
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST ?? "127.0.0.1",
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER ?? "root",
    password: process.env.DB_PASS ?? "",
  });
  await conn.query(
    "CREATE DATABASE IF NOT EXISTS motodub_test CHARACTER SET utf8mb4",
  );
  await conn.end();

  execSync("npm run migrate", { stdio: "pipe", env: process.env });
  execSync("npm run seed", { stdio: "pipe", env: process.env });

  ({ sequelize } = await import("../src/config/db.js"));
  ({ User, Driver } = await import("../src/models/index.js"));
  const { createApp } = await import("../src/app.js");
  const http_ = await import("node:http");

  app = createApp();
  server = http_.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  await sequelize.authenticate();

  // Idempotent start: drop leftovers of a crashed earlier run.
  const { Ride } = await import("../src/models/index.js");
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
  });
  const stale = await User.findAll({
    where: { email: { [Op.in]: [CUSTOMER_EMAIL, DRIVER_EMAIL] } },
  });
  if (stale.length > 0) {
    await Driver.destroy({ where: { user_id: stale.map((u) => u.id) } });
    await User.destroy({ where: { id: stale.map((u) => u.id) } });
  }

  await register("FCM Cust", CUSTOMER_EMAIL, "customer");
  await register("FCM Driver", DRIVER_EMAIL, "driver");

  customer.token = await login(CUSTOMER_EMAIL);
  driver.token = await login(DRIVER_EMAIL);
  const custRow = await User.findOne({ where: { email: CUSTOMER_EMAIL } });
  const driverRow = await User.findOne({ where: { email: DRIVER_EMAIL } });
  customer.id = custRow.id;
  driver.id = driverRow.id;
}, 30000);

afterAll(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  // Leave NOTHING behind for sibling suites sharing motodub_test.
  if (sequelize) {
    const { Ride } = await import("../src/models/index.js");
    await Ride.destroy({
      where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
    });
    await Driver.destroy({
      where: { user_id: { [Op.in]: [customer.id, driver.id].filter(Boolean) } },
    });
    await User.destroy({
      where: { id: { [Op.in]: [customer.id, driver.id].filter(Boolean) } },
    });
    await sequelize.close();
  }
  process.env.DB_NAME = ORIGINAL_DB_NAME;
});

describe("POST /api/users/fcm-token", () => {
  it("requires authentication", async () => {
    const res = await request(app)
      .post("/api/users/fcm-token")
      .send({ token: "some-fcm-token" });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("stores the token on the caller's own row only", async () => {
    const res = await authed(customer.token)
      .post("/api/users/fcm-token")
      .send({ token: "fcm-token-customer-abc" });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const custRow = await User.findByPk(customer.id);
    expect(custRow.fcm_token).toBe("fcm-token-customer-abc");
    // Another user's row is untouched.
    const otherRow = await User.findOne({ where: { email: "srey@taxi.demo" } });
    expect(otherRow === null || otherRow.fcm_token === null).toBe(true);
  });
});

describe("ride events with FCM unconfigured", () => {
  it("complete a full ride flow with push disabled and log no crash", async () => {
    const errorSpy = jest.spyOn(console, "error");

    // Driver goes bookable: vehicle profile + online.
    const profileRes = await authed(driver.token).post("/api/drivers").send({
      car_model: "Honda Click",
      plate: `${MARKER} 1AA`,
      license_no: `${MARKER} LIC`,
      price_per_km: 4000,
    });
    expect(profileRes.status).toBe(201);
    const onlineRes = await authed(driver.token)
      .patch("/api/drivers/online")
      .send({ online: true });
    expect(onlineRes.status).toBe(200);
    // Admin verification is Task 6.x — suites flip the flag directly
    // (same as ride-create/socket-events fixtures).
    const driverRow = await Driver.findOne({ where: { user_id: driver.id } });
    await driverRow.update({ verified: true });
    driver.driverRowId = driverRow.id;

    // Booking #1 — requested event pushes to a driver WITHOUT a token: no-op.
    let res = await authed(customer.token)
      .post("/api/rides")
      .send(bookingBody(driver.driverRowId, "one"));
    expect(res.status).toBe(201);
    const rideId = res.body.data.id;

    // Driver registers a token, then the ride is cancelled (updated event →
    // both participants): push runs with a token present but messaging still
    // unconfigured — must stay a silent no-op.
    await authed(driver.token)
      .post("/api/users/fcm-token")
      .send({ token: "fcm-token-driver-xyz" });
    res = await authed(customer.token).post(`/api/rides/${rideId}/cancel`);
    expect(res.status).toBe(200);

    // Booking #2 — requested event now targets a driver WITH a token.
    res = await authed(customer.token)
      .post("/api/rides")
      .send(bookingBody(driver.driverRowId, "two"));
    expect(res.status).toBe(201);
    const secondRideId = res.body.data.id;
    await authed(customer.token).post(`/api/rides/${secondRideId}/cancel`);

    expect(errorSpy).not.toHaveBeenCalled();
    errorSpy.mockRestore();
  });
});
