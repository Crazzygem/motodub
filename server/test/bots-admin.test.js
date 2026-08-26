import { execSync } from "node:child_process";
import http from "node:http";
import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";

// Seth directive — server-side bots manager driven from the admin app.
//
// Isolation: motodub_test like every suite that mutates rows. This suite owns
// the bot accounts (bot-*@taxi.demo exist nowhere in the seed) and spins a
// REAL http+socket.io listener on an ephemeral port; BOTS_BASE_URL points the
// embedded manager at it because the manager speaks the same REST + Socket.IO
// protocol as the CLI — loopback is the honest exercise. DB_NAME and
// BOTS_BASE_URL must be set BEFORE the dynamic imports resolve config/db.js
// and before the first POST lazily creates the bots singleton.
const ORIGINAL_DB_NAME = process.env.DB_NAME;
const ORIGINAL_BOTS_BASE_URL = process.env.BOTS_BASE_URL;
process.env.DB_NAME = "motodub_test";
process.env.SWEEP_DISABLED = "1"; // no 10s sweeper racing the lifecycle

const BOT_EMAILS = [
  "bot-c1@taxi.demo",
  "bot-c2@taxi.demo",
  "bot-c3@taxi.demo",
  "bot-d1@taxi.demo",
  "bot-d2@taxi.demo",
  "bot-d3@taxi.demo",
];
const ACTIVE_RIDES = ["requested", "accepted", "en_route", "in_progress"];

let sequelize;
let User;
let Driver;
let Ride;
let app;
let server;
let baseUrl;

async function login(email, password) {
  const res = await request(app).post("/api/login").send({ email, password });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

function get(token, url) {
  return request(app).get(url).set("Authorization", `Bearer ${token}`);
}

async function post(token, url, body) {
  const req = request(app).post(url).set("Authorization", `Bearer ${token}`);
  return body === undefined ? await req : await req.send(body);
}

function del(token, url) {
  return request(app).delete(url).set("Authorization", `Bearer ${token}`);
}

function patch(token, url, body) {
  return request(app)
    .patch(url)
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

/** Retry while async settles race the assertion (bootstrap/stop are async). */
async function until(getter, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  let last;
  for (;;) {
    last = await getter();
    if (last) return last;
    if (Date.now() > deadline) return false;
    await new Promise((r) => setTimeout(r, 250));
  }
}

beforeAll(async () => {
  await import("dotenv/config");

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
  ({ User, Driver, Ride } = await import("../src/models/index.js"));
  const { createApp } = await import("../src/app.js");
  const { attach } = await import("../src/realtime/socket.js");

  app = createApp();
  server = http.createServer(app);
  attach(server);
  await new Promise((resolve) => server.listen(0, resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  // The embedded manager is created lazily on the FIRST start call — this
  // must point at our own listener before that happens.
  process.env.BOTS_BASE_URL = baseUrl;
  await sequelize.authenticate();
}, 30000);

afterAll(async () => {
  // Defensive stop so open handles never wedge the jest worker.
  const adminToken =
    app && (await login("admin@taxi.demo", "Admin@123").catch(() => null));
  if (adminToken) await del(adminToken, "/api/admin/bots");
  if (server) await new Promise((resolve) => server.close(resolve));

  if (sequelize) {
    // Leave NOTHING behind — bot rows would collide with the next run's
    // bootstrap and pollute sibling suites' online-driver counts.
    const stale = await User.findAll({
      where: { email: { [Op.in]: BOT_EMAILS } },
    });
    if (stale.length > 0) {
      await Driver.destroy({ where: { user_id: stale.map((u) => u.id) } });
      await User.destroy({ where: { id: stale.map((u) => u.id) } });
    }
    await sequelize.close();
  }
  process.env.DB_NAME = ORIGINAL_DB_NAME;
  process.env.BOTS_BASE_URL = ORIGINAL_BOTS_BASE_URL;
});

describe("bots admin RBAC gates (§4 matrix)", () => {
  const BOT_PATHS = [
    ["get", "/api/admin/bots/status"],
    ["post", "/api/admin/bots"],
    ["delete", "/api/admin/bots"],
    ["patch", "/api/admin/drivers/999999"],
  ];

  it("rejects unauthenticated requests with UNAUTHORIZED on every route", async () => {
    for (const [method, url] of BOT_PATHS) {
      const res = await request(app)[method](url);
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe("UNAUTHORIZED");
    }
  });

  it("rejects customer and driver tokens with FORBIDDEN on every route", async () => {
    const sreyToken = await login("srey@taxi.demo", "Demo@123");
    const daraToken = await login("dara@taxi.demo", "Demo@123");

    for (const token of [sreyToken, daraToken]) {
      for (const [method, url] of BOT_PATHS) {
        const res = await request(app)
          [method](url)
          .set("Authorization", `Bearer ${token}`);
        expect(res.status).toBe(403);
        expect(res.body.error.code).toBe("FORBIDDEN");
      }
    }
  });

  it("rejects an out-of-range count with VALIDATION_ERROR (admin)", async () => {
    const adminToken = await login("admin@taxi.demo", "Admin@123");
    for (const count of [0, 4]) {
      const res = await post(adminToken, "/api/admin/bots", { count });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe("VALIDATION_ERROR");
    }
  });
});

describe("POST/GET/DELETE /api/admin/bots lifecycle", () => {
  let adminToken;
  let botDriverRowId;
  let botDriverUserId;

  it("reports running:false before anything starts", async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");
    const res = await get(adminToken, "/api/admin/bots/status");

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      running: false,
      drivers: [],
      ridesSpawned: 0,
      uptimeSec: 0,
      lastRideAt: null,
    });
  });

  it("starts with count:1 and reports one verified online driver", async () => {
    const res = await post(adminToken, "/api/admin/bots", { count: 1 });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.running).toBe(true);
    expect(res.body.data.drivers).toHaveLength(1);
    expect(typeof res.body.data.uptimeSec).toBe("number");
    expect(res.body.data.ridesSpawned).toBe(0);

    const row = await until(async () =>
      Driver.findOne({
        include: [
          {
            model: User,
            where: { email: "bot-d1@taxi.demo" },
          },
        ],
      }),
    );
    expect(row).toBeTruthy();
    expect(row.verified).toBe(true);
    expect(row.online).toBe(true);
  });

  it("refuses a double start with 409 BOT_ALREADY_RUNNING", async () => {
    const res = await post(adminToken, "/api/admin/bots", { count: 2 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("BOT_ALREADY_RUNNING");

    // Still exactly one managed driver after the refused start.
    const status = await get(adminToken, "/api/admin/bots/status");
    expect(status.body.data.drivers).toHaveLength(1);
  });

  it("exposes the live driver through status (online + gallery)", async () => {
    const ok = await until(async () => {
      const res = await get(adminToken, "/api/admin/bots/status");
      const d = res.body.data.drivers[0];
      return res.body.data.running && d?.online && d?.verified;
    });
    expect(ok).toBe(true);

    const res = await get(adminToken, "/api/admin/bots/status");
    expect(Object.keys(res.body.data).sort()).toEqual(
      ["drivers", "lastRideAt", "ridesSpawned", "running", "uptimeSec"].sort(),
    );
    expect(Object.keys(res.body.data.drivers[0]).sort()).toEqual(
      ["email", "online", "vehiclePhotos", "verified"].sort(),
    );
    expect(Array.isArray(res.body.data.drivers[0].vehiclePhotos)).toBe(true);
  });

  it("lets admin edit the bot driver like any other (PATCH persists)", async () => {
    const list = await get(adminToken, "/api/admin/drivers");
    const botRow = list.body.data.find((d) => d.email === "bot-d1@taxi.demo");
    botDriverRowId = botRow.driver_id;
    botDriverUserId = botRow.user_id;

    const res = await patch(adminToken, `/api/admin/drivers/${botDriverRowId}`, {
      name: "Bot Dara Edited",
      car_model: "Honda Dream 50cc",
      price_per_km: "1.75",
    });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      driver_id: botDriverRowId,
      name: "Bot Dara Edited",
      car_model: "Honda Dream 50cc",
      price_per_km: 1.75,
    });

    // Read back through the plain admin feed — persistence over echo.
    const feed = await get(adminToken, "/api/admin/drivers");
    const reread = feed.body.data.find(
      (d) => d.driver_id === botDriverRowId,
    );
    expect(reread.name).toBe("Bot Dara Edited");
    expect(reread.car_model).toBe("Honda Dream 50cc");
    expect(reread.price_per_km).toBe(1.75);
  });

  it("stops cleanly: running:false and the bot driver offlined", async () => {
    const res = await del(adminToken, "/api/admin/bots");

    expect(res.status).toBe(200);
    expect(res.body.data.running).toBe(false);

    const offlined = await until(async () => {
      const row = await Driver.findByPk(botDriverRowId);
      return row && row.online === false;
    });
    expect(offlined).toBe(true);

    const status = await get(adminToken, "/api/admin/bots/status");
    expect(status.body.data.running).toBe(false);
    expect(status.body.data.drivers).toEqual([]);
  });

  it("is idempotent when stopped (DELETE again → {running:false})", async () => {
    const res = await del(adminToken, "/api/admin/bots");

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ running: false });
  });

  it("leaves no active rides behind after the run", async () => {
    const leftovers = await Ride.count({
      where: {
        status: { [Op.in]: ACTIVE_RIDES },
        [Op.or]: [{ customer_id: botDriverUserId }, { driver_id: botDriverUserId }],
      },
    });
    expect(leftovers).toBe(0);
  });
});

describe("PATCH /api/admin/drivers/:id", () => {
  let adminToken;
  let fixtureUserId;
  let fixtureRowId;
  const stamp = Date.now();

  beforeAll(async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");
    // Dedicated actor (suspend-test convention): owned by THIS suite so the
    // shared seeded drivers stay untouched for parallel workers.
    const user = await User.create({
      role: "driver",
      name: "Patch Target",
      phone: "012345682",
      email: `${stamp}-patch-driver@test.demo`,
      password_hash: "not-a-real-login",
    });
    const row = await Driver.create({
      user_id: user.id,
      car_model: "Yamaha Sirius",
      plate: "PP-8Z-8888",
      license_no: "KH-DL-8888",
      verified: true,
      online: false,
      price_per_km: "1.10",
    });
    fixtureUserId = user.id;
    fixtureRowId = row.id;
  });

  afterAll(async () => {
    if (fixtureRowId) await Driver.destroy({ where: { id: fixtureRowId } });
    if (fixtureUserId) await User.destroy({ where: { id: fixtureUserId } });
  });

  it("edits vehicle fields only and echoes the full row", async () => {
    const res = await patch(
      adminToken,
      `/api/admin/drivers/${fixtureRowId}`,
      { plate: "PP-77-7777", license_no: "KH-DL-7777" },
    );

    expect(res.status).toBe(200);
    // Wire shape mirrors verify/suspend (toDriverItem — no license_no there),
    // so the hidden field's persistence is asserted against the row itself.
    expect(res.body.data).toMatchObject({
      driver_id: fixtureRowId,
      plate: "PP-77-7777",
      car_model: "Yamaha Sirius", // untouched field survives
    });
    const row = await Driver.findByPk(fixtureRowId);
    expect(row.license_no).toBe("KH-DL-7777");
  });

  it("edits account fields (name, phone) alongside vehicle fields", async () => {
    const res = await patch(
      adminToken,
      `/api/admin/drivers/${fixtureRowId}`,
      { name: "Patched Name", phone: "+855 12 345 678" },
    );

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      name: "Patched Name",
      phone: "+855 12 345 678",
    });
  });

  it("rejects an empty payload with VALIDATION_ERROR", async () => {
    const res = await patch(adminToken, `/api/admin/drivers/${fixtureRowId}`, {});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects rule violations with VALIDATION_ERROR (same rules as driver PATCH)", async () => {
    for (const body of [
      { price_per_km: -1 },
      { car_model: "" },
      { phone: "abc" },
    ]) {
      const res = await patch(
        adminToken,
        `/api/admin/drivers/${fixtureRowId}`,
        body,
      );
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe("VALIDATION_ERROR");
    }
  });

  it("strips immutable fields (email stays put)", async () => {
    const res = await patch(adminToken, `/api/admin/drivers/${fixtureRowId}`, {
      email: "hijack@evil.demo",
    });

    expect(res.status).toBe(400); // unknown keys stripped → empty → refine fails
    const row = await Driver.findByPk(fixtureRowId, {
      include: [{ model: User }],
    });
    expect(row.User.email).toBe(`${stamp}-patch-driver@test.demo`);
  });

  it("returns NOT_FOUND for an unknown driver id", async () => {
    const res = await patch(adminToken, "/api/admin/drivers/999999", {
      name: "Nobody",
    });
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });

  it("rejects a malformed id with VALIDATION_ERROR", async () => {
    const res = await patch(adminToken, "/api/admin/drivers/abc", {
      name: "Nobody",
    });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});
