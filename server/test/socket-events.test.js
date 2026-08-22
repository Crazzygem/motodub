import { execSync } from "node:child_process";
import http from "node:http";
import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";
import { io } from "socket.io-client";

// Task 4.4 — Socket.IO handshake, rooms and ride events (ARCHITECTURE §6).
//
// Isolation: motodub_test like ride-flow.test.js, but with DEDICATED actors
// registered below — this suite parks an active ride mid-test, and borrowing
// the shared srey/dara fixtures would collide with ride-flow running in a
// parallel jest worker. DB_NAME must be set BEFORE the dynamic imports
// resolve config/db.js.
const ORIGINAL_DB_NAME = process.env.DB_NAME;
process.env.DB_NAME = "motodub_test";

const MARKER = "[socket-events-test]";
const CUSTOMER_EMAIL = "socket-cust@taxi.demo";
const DRIVER_EMAIL = "socket-driver@taxi.demo";

let sequelize;
let Ride;
let User;
let Driver;
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

// Negative probe: proves room isolation — an event routed to the wrong room
// fails this suite even though every happy-path assertion passes.
function expectNoEvent(socket, event, ms = 400) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    socket.once(event, () => {
      clearTimeout(timer);
      reject(new Error(`"${event}" leaked to the wrong client`));
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
  ({ Ride, User, Driver } = await import("../src/models/index.js"));
  const { createApp } = await import("../src/app.js");
  const { attach } = await import("../src/realtime/socket.js");

  app = createApp();
  server = http.createServer(app);
  attach(server);
  await new Promise((resolve) => server.listen(0, resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  await sequelize.authenticate();

  // Idempotent start: drop leftovers of a crashed earlier run (rides first —
  // they reference the users we are about to recreate).
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
  });
  const stale = await User.findAll({
    where: { email: { [Op.in]: [CUSTOMER_EMAIL, DRIVER_EMAIL] } },
  });
  if (stale.length > 0) {
    await Driver.destroy({ where: { user_id: stale.map((u) => u.id) } });
    await User.destroy({
      where: { id: stale.map((u) => u.id) },
    });
  }

  // Dedicated actors for this suite (see isolation note at the top).
  await register("Socket Cust", CUSTOMER_EMAIL, "customer");
  await register("Socket Driver", DRIVER_EMAIL, "driver");
}, 30000);

afterAll(async () => {
  for (const socket of sockets.splice(0)) socket.disconnect();
  if (server) await new Promise((resolve) => server.close(resolve));
  // Leave NOTHING behind — this suite stops mid-flow (accepted ride), and
  // sibling suites sharing motodub_test would trip RIDE_BUSY_* on our actors
  // or fail on duplicate emails next run.
  if (sequelize) {
    await Ride.destroy({
      where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
    });
    const ours = await User.findAll({
      where: { email: { [Op.in]: [CUSTOMER_EMAIL, DRIVER_EMAIL] } },
    });
    if (ours.length > 0) {
      await Driver.destroy({ where: { user_id: ours.map((u) => u.id) } });
      await User.destroy({ where: { id: ours.map((u) => u.id) } });
    }
    await sequelize.close();
  }
  process.env.DB_NAME = ORIGINAL_DB_NAME;
});

describe("socket.io handshake", () => {
  let customerToken;

  beforeAll(async () => {
    customerToken = await login(CUSTOMER_EMAIL, "Demo@1234");
  });

  it("rejects a connection whose token is not a valid JWT", async () => {
    await expect(connect("not-a-jwt")).rejects.toThrow(
      /Invalid or expired token/,
    );
  });

  it("accepts a valid token", async () => {
    const socket = await connect(customerToken);

    // Personal-room delivery itself is proven by the accept flow below.
    expect(socket.connected).toBe(true);
  });
});

describe("accept flow over REST announces itself on the socket", () => {
  let customerToken;
  let driverToken;
  let adminToken;
  let customerId;
  let driverId;
  let driverRowId;

  beforeAll(async () => {
    customerToken = await login(CUSTOMER_EMAIL, "Demo@1234");
    driverToken = await login(DRIVER_EMAIL, "Demo@1234");
    adminToken = await login("admin@taxi.demo", "Admin@123");

    const customer = await User.findOne({
      where: { email: CUSTOMER_EMAIL },
    });
    const driver = await User.findOne({ where: { email: DRIVER_EMAIL } });
    customerId = customer.id;
    driverId = driver.id;

    // Vehicle profile over REST; verification has no endpoint yet (Task 6.x),
    // and the test DB is disposable — flip it directly, as the seeders do.
    const profile = await post(driverToken, "/api/drivers", {
      car_model: "Honda Dream",
      plate: "PP-SOCKET-1",
      license_no: "KH-DL-SOCKET",
      price_per_km: 1,
    });
    expect(profile.status).toBe(201);
    await Driver.update(
      { verified: true },
      { where: { user_id: driverId } },
    );
    const online = await patch(driverToken, "/api/drivers/online", {
      online: true,
    });
    expect(online.status).toBe(200);

    const row = await Driver.findOne({ where: { user_id: driverId } });
    driverRowId = row.id;
  });

  it("delivers ride:requested to the driver only, ride:accepted to customer and admin", async () => {
    const driverSocket = await connect(driverToken);
    const customerSocket = await connect(customerToken);
    const adminSocket = await connect(adminToken);

    // Listeners armed BEFORE the REST calls — events may beat the response.
    const driverRequested = waitForEvent(driverSocket, "ride:requested");
    const customerAccepted = waitForEvent(customerSocket, "ride:accepted");
    const adminAccepted = waitForEvent(adminSocket, "ride:accepted");

    const created = await post(
      customerToken,
      "/api/rides",
      bookingBody(driverRowId, "flow"),
    );
    expect(created.status).toBe(201);

    const requested = await driverRequested;
    expect(requested).toMatchObject({
      status: "requested",
      customerId,
      driverId,
    });
    const rideId = requested.rideId;
    expect(Number.isInteger(rideId)).toBe(true);

    // §6 rooms: ride:requested targets user:{driverId} — nobody else hears it.
    await expectNoEvent(adminSocket, "ride:requested");

    const accepted = await post(driverToken, `/api/rides/${rideId}/accept`);
    expect(accepted.status).toBe(200);
    expect(accepted.body.data.status).toBe("accepted");

    const expectedPayload = {
      rideId,
      status: "accepted",
      customerId,
      driverId,
    };
    expect(await customerAccepted).toMatchObject(expectedPayload);
    expect(await adminAccepted).toMatchObject(expectedPayload);

    // The ride really persisted as accepted (REST stays the source of truth).
    const row = await Ride.findByPk(rideId);
    expect(row.status).toBe("accepted");
  });
});
