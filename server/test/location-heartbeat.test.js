import { execSync } from "node:child_process";
import http from "node:http";
import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";
import { io } from "socket.io-client";

// Task 4.5 — location heartbeat (`location:update` → drivers row +
// `driver:location` fan-out) and the staleness sweep (ARCHITECTURE §6).
//
// Isolation: motodub_test like socket-events.test.js, with DEDICATED actors
// registered below — the sweep test mutates heartbeat columns, which must
// never touch actors owned by suites running in parallel jest workers.
// DB_NAME must be set BEFORE the dynamic imports resolve config/db.js.
const ORIGINAL_DB_NAME = process.env.DB_NAME;
process.env.DB_NAME = "motodub_test";

const MARKER = "[location-heartbeat-test]";
const DRIVER_EMAIL = "loc-driver@taxi.demo";
const BARE_DRIVER_EMAIL = "loc-bare-driver@taxi.demo"; // no Driver row
const CUSTOMER_EMAIL = "loc-cust@taxi.demo";

let sequelize;
let User;
let Driver;
let sweepStaleDrivers;
let app;
let server;
let baseUrl;
const sockets = [];

async function login(email, password) {
  const res = await request(app).post("/api/login").send({ email, password });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

async function register(name, email, role) {
  const res = await request(app).post("/api/register").send({
    name,
    phone: "+855 900 000",
    email,
    password: "Demo@1234",
    role,
  });
  expect(res.status).toBe(201);
}

function post(token, url, body) {
  return request(app)
    .post(url)
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

function patch(token, url, body) {
  return request(app)
    .patch(url)
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

function waitForEvent(socket, event, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`timed out waiting for "${event}"`)),
      timeoutMs,
    );
    socket.once(event, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

// Room-isolation probe (same pattern as socket-events.test.js).
function expectNoEvent(socket, event, ms = 400) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    socket.once(event, () => {
      clearTimeout(timer);
      reject(new Error(`"${event}" leaked to a client outside the room`));
    });
  });
}

function connect(token) {
  const socket = io(baseUrl, { auth: { token } });
  sockets.push(socket);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("socket connect timed out")),
      5000,
    );
    socket.once("connect", () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.once("connect_error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

async function driverRowFor(email) {
  const user = await User.findOne({ where: { email } });
  return Driver.findOne({ where: { user_id: user.id } });
}

beforeAll(async () => {
  await import("dotenv/config");

  // Self-bootstrapping test setup (same as socket-events.test.js).
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
  ({ sweepStaleDrivers } = await import("../src/scripts/staleness-sweep.js"));
  const { createApp } = await import("../src/app.js");
  const { attach } = await import("../src/realtime/socket.js");

  app = createApp();
  server = http.createServer(app);
  attach(server);
  await new Promise((resolve) => server.listen(0, resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  await sequelize.authenticate();

  // Idempotent start: drop leftovers of a crashed earlier run.
  const stale = await User.findAll({
    where: {
      email: {
        [Op.in]: [DRIVER_EMAIL, BARE_DRIVER_EMAIL, CUSTOMER_EMAIL],
      },
    },
  });
  if (stale.length > 0) {
    await Driver.destroy({ where: { user_id: stale.map((u) => u.id) } });
    await User.destroy({ where: { id: stale.map((u) => u.id) } });
  }

  // Dedicated actors for this suite (see isolation note at the top).
  await register("Location Driver", DRIVER_EMAIL, "driver");
  await register("Bare Driver", BARE_DRIVER_EMAIL, "driver");
  await register("Location Cust", CUSTOMER_EMAIL, "customer");
}, 30000);

afterAll(async () => {
  for (const socket of sockets.splice(0)) socket.disconnect();
  if (server) await new Promise((resolve) => server.close(resolve));
  if (sequelize) {
    const ours = await User.findAll({
      where: {
        email: {
          [Op.in]: [DRIVER_EMAIL, BARE_DRIVER_EMAIL, CUSTOMER_EMAIL],
        },
      },
    });
    if (ours.length > 0) {
      await Driver.destroy({ where: { user_id: ours.map((u) => u.id) } });
      await User.destroy({ where: { id: ours.map((u) => u.id) } });
    }
    await sequelize.close();
  }
  process.env.DB_NAME = ORIGINAL_DB_NAME;
});

describe("location:update heartbeat", () => {
  let driverToken;
  let customerId;

  beforeAll(async () => {
    driverToken = await login(DRIVER_EMAIL, "Demo@1234");
    const customer = await User.findOne({ where: { email: CUSTOMER_EMAIL } });
    customerId = customer.id;

    const driver = await User.findOne({ where: { email: DRIVER_EMAIL } });
    const profile = await post(driverToken, "/api/drivers", {
      car_model: "Honda Dream",
      plate: "PP-LOC-1",
      license_no: "KH-DL-LOC",
      price_per_km: 1,
    });
    expect(profile.status).toBe(201);

    // Start online so the sweep test can prove the flip on this very row.
    const online = await patch(driverToken, "/api/drivers/online", {
      online: true,
    });
    expect(online.status).toBe(200);
  });

  it("persists lat/lng and bumps the updated_at heartbeat", async () => {
    const socket = await connect(driverToken);

    // Backdate so the bump below is unambiguous. Staleness math happens in
    // SQL against the DB's own clock — client-side Date formatting proved
    // timezone-fragile, and timestamp-only Model.update values are silently
    // dropped anyway (Sequelize reserves the column).
    const row = await driverRowFor(DRIVER_EMAIL);
    await sequelize.query(
      "UPDATE drivers SET updated_at = NOW() - INTERVAL 60 SECOND WHERE id = :id",
      { replacements: { id: row.id } },
    );
    // Second-precision DATETIME: compare against the backdated value so the
    // bump cannot land "in the same second" as the reference.
    const before = new Date(
      (await driverRowFor(DRIVER_EMAIL)).updated_at,
    ).getTime();

    socket.emit("location:update", { lat: 11.5678, lng: 104.9123 });

    // Poll the row: the heartbeat must land within a sane window and move
    // the heartbeat strictly past its backdated value.
    let fresh = null;
    for (let i = 0; i < 30 && !fresh; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 100));
      const candidate = await driverRowFor(DRIVER_EMAIL);
      if (new Date(candidate.updated_at).getTime() > before) {
        fresh = candidate;
      }
    }
    expect(fresh).not.toBeNull();
    expect(Number(fresh.lat)).toBeCloseTo(11.5678, 5);
    expect(Number(fresh.lng)).toBeCloseTo(104.9123, 5);
  });

  it("broadcasts driver:location only into the location:{driverId} room", async () => {
    const driverSocket = await connect(driverToken);
    const followerSocket = await connect(await login(CUSTOMER_EMAIL, "Demo@1234"));
    const outsiderSocket = await connect(await login(BARE_DRIVER_EMAIL, "Demo@1234"));

    const driverUser = await User.findOne({ where: { email: DRIVER_EMAIL } });
    followerSocket.emit("join:location", { driverId: driverUser.id });

    // Join is processed synchronously on the server once delivered; a short
    // settle avoids racing the emit against the still-in-flight join frame.
    await new Promise((resolve) => setTimeout(resolve, 100));

    const received = waitForEvent(followerSocket, "driver:location");
    const outsiderSilence = expectNoEvent(outsiderSocket, "driver:location");

    driverSocket.emit("location:update", { lat: 11.5501, lng: 104.9002 });

    // §6 payload contract: {lat, lng}.
    expect(await received).toEqual({ lat: 11.5501, lng: 104.9002 });
    await outsiderSilence;
  });

  it("ignores location:update from a non-driver role silently", async () => {
    const customerSocket = await connect(
      await login(CUSTOMER_EMAIL, "Demo@1234"),
    );

    // Must neither crash nor persist anything anywhere.
    customerSocket.emit("location:update", { lat: 1.2345, lng: 5.6789 });
    await new Promise((resolve) => setTimeout(resolve, 200));

    const row = await driverRowFor(CUSTOMER_EMAIL);
    expect(row).toBeNull(); // customers have no driver row at all

    // And the seeded driver row was untouched by the customer's emit.
    const driverRow = await driverRowFor(DRIVER_EMAIL);
    expect(Number(driverRow.lat)).toBeCloseTo(11.5501, 5);
  });

  it("ignores location:update when the driver has no vehicle profile", async () => {
    const bareToken = await login(BARE_DRIVER_EMAIL, "Demo@1234");
    const socket = await connect(bareToken);

    // No Driver row exists for this user — silent ignore, no crash.
    socket.emit("location:update", { lat: 9.9999, lng: 8.8888 });
    await new Promise((resolve) => setTimeout(resolve, 200));

    const row = await driverRowFor(BARE_DRIVER_EMAIL);
    expect(row).toBeNull();
  });
});

describe("staleness sweep", () => {
  it("flips online=false for heartbeats older than 15s and leaves fresh ones alone", async () => {
    // Backdate the dedicated actor's heartbeat while it is online=true
    // (SQL-side clock math; see the note in the heartbeat test above).
    const row = await driverRowFor(DRIVER_EMAIL);
    await sequelize.query(
      "UPDATE drivers SET updated_at = NOW() - INTERVAL 16 SECOND WHERE id = :id",
      { replacements: { id: row.id } },
    );

    // Run the flip inside a transaction and roll it back: the assertions see
    // exactly what the sweep did, while parallel jest workers sharing
    // motodub_test are shielded from this global UPDATE entirely.
    const transaction = await sequelize.transaction();
    try {
      const flipped = await sweepStaleDrivers({ transaction });

      const swept = await Driver.findOne({
        where: { id: row.id },
        transaction,
      });
      expect(swept.online).toBe(false);
      expect(flipped).toBeGreaterThanOrEqual(1); // our actor among them

      // A freshly-heartbeating driver must survive the sweep untouched.
      // (online=true re-set in-txn; the auto-stamp refreshes updated_at.)
      await Driver.update(
        { online: true },
        { where: { id: row.id }, transaction },
      );
      await sweepStaleDrivers({ transaction });
      const stillOnline = await Driver.findOne({
        where: { id: row.id },
        transaction,
      });
      expect(stillOnline.online).toBe(true);
    } finally {
      await transaction.rollback();
    }

    // Committed state is unchanged by the rolled-back probe.
    const after = await driverRowFor(DRIVER_EMAIL);
    expect(after.online).toBe(true);
  });
});
