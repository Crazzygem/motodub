import { execSync } from "node:child_process";
import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";

// Task 6.1 — admin endpoints over REST (ARCHITECTURE §4 admin matrix rows +
// §2 suspended-driver invariant via RideService.create).
//
// Isolation: motodub_test like ride-flow.test.js — verify/suspend mutate
// seeded actors and must never touch the dev database. DB_NAME must be set
// BEFORE the dynamic imports below resolve config/db.js (a static import
// would hoist above this line and bind the dev database instead). The env
// override is restored in afterAll for any sibling suite sharing this
// jest worker.
const ORIGINAL_DB_NAME = process.env.DB_NAME;
process.env.DB_NAME = "motodub_test";

let sequelize;
let User;
let Driver;
let Ride;
let app;
let fixtureEmail; // per-run customer created for the suspend booking attempt
let suspDriverRow; // dedicated suspend-scenario driver (this suite's actor)
let suspDriverUserId;
let suspendFixtureEmails = []; // emails of every user row this suite created

async function login(email, password) {
  const res = await request(app).post("/api/login").send({ email, password });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

async function post(token, url, body) {
  const req = request(app).post(url).set("Authorization", `Bearer ${token}`);
  return body === undefined ? await req : await req.send(body);
}

function get(token, url) {
  return request(app).get(url).set("Authorization", `Bearer ${token}`);
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
      address: `[admin-test] pickup ${tag}`,
    },
    dropoff: {
      lat: 11.5449,
      lng: 104.8922,
      address: `[admin-test] dropoff ${tag}`,
    },
  };
}

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

// Mirror of stats.service.getStats() math — the expectation is derived from
// what the seed ACTUALLY wrote, not hardcoded, so reruns against an aged
// motodub_test stay honest (seeded created_at only dates from the FIRST seed).
async function deriveExpectedStats() {
  const today = startOfToday();
  const [ridesToday, completedToday, onlineDrivers, requestedNow, rated] =
    await Promise.all([
      Ride.count({ where: { created_at: { [Op.gte]: today } } }),
      Ride.count({
        where: { status: "completed", updated_at: { [Op.gte]: today } },
      }),
      Driver.count({ where: { online: true } }),
      Ride.count({ where: { status: "requested" } }),
      User.findAll({
        attributes: [[sequelize.fn("AVG", sequelize.col("rating")), "avg"]],
        where: { role: "driver" },
        raw: true,
      }),
    ]);
  const avg = parseFloat(rated[0]?.avg);
  return {
    rides_today: ridesToday,
    completed_today: completedToday,
    online_drivers: onlineDrivers,
    avg_rating: Number.isNaN(avg) ? null : Number(avg.toFixed(2)),
    requested_now: requestedNow,
  };
}

/**
 * ride-flow runs in a parallel jest worker against this same motodub_test —
 * a stats read is only meaningful if the ground truth is identical on both
 * sides of the HTTP round-trip. Retry while a concurrent writer moves the
 * baseline; assert only once everything is stable.
 */
async function expectStatsMatchesDb(adminToken) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const expected = await deriveExpectedStats();
    const res = await get(adminToken, "/api/admin/stats");
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const recheck = await deriveExpectedStats();
    if (JSON.stringify(expected) !== JSON.stringify(recheck)) continue;
    if (JSON.stringify(res.body.data) !== JSON.stringify(recheck)) continue;
    expect(res.body.data).toEqual(recheck);
    return;
  }
  throw new Error("stats baseline kept moving under 5 attempts");
}

beforeAll(async () => {
  await import("dotenv/config");
  // Shell/env value above wins — dotenv never overrides existing variables.

  // Self-bootstrapping setup (ride-flow convention): create, migrate and
  // seed motodub_test through the project's own tooling.
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

  app = createApp();
  await sequelize.authenticate();

  // Idempotent start (ride-flow convention): a crashed earlier run of this
  // suite may have left [admin-test] rides that block fresh bookings.
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: "%[admin-test]%" } },
  });
});

afterAll(async () => {
  // Restore what this suite mutated so anything sharing the test DB later
  // starts from canonical seed flags.
  const vuthy = await User.findOne({ where: { email: "vuthy@taxi.demo" } });
  if (vuthy) {
    await Driver.update({ verified: false }, { where: { user_id: vuthy.id } });
  }
  // FK order: rides (none survive — the suspend booking is refused) →
  // dedicated driver → fixture users.
  if (suspDriverRow) await suspDriverRow.destroy();
  const allFixtureEmails = [fixtureEmail, ...suspendFixtureEmails].filter(Boolean);
  if (allFixtureEmails.length > 0) {
    await User.destroy({ where: { email: allFixtureEmails } });
  }

  if (sequelize) await sequelize.close();
  process.env.DB_NAME = ORIGINAL_DB_NAME;
});

describe("admin RBAC gates (§4 matrix)", () => {
  // 999999 exists nowhere — even a broken gate could not mutate anything.
  const ADMIN_PATHS = [
    ["get", "/api/admin/stats"],
    ["get", "/api/admin/drivers"],
    ["post", "/api/admin/drivers/999999/verify"],
    ["post", "/api/admin/drivers/999999/suspend"],
    ["get", "/api/admin/rides"],
  ];

  it("rejects unauthenticated requests with UNAUTHORIZED on every route", async () => {
    for (const [method, url] of ADMIN_PATHS) {
      const res = await request(app)[method](url);
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe("UNAUTHORIZED");
    }
  });

  it("rejects customer and driver tokens with FORBIDDEN on every route", async () => {
    const sreyToken = await login("srey@taxi.demo", "Demo@123");
    const daraToken = await login("dara@taxi.demo", "Demo@123");

    for (const token of [sreyToken, daraToken]) {
      for (const [method, url] of ADMIN_PATHS) {
        const res = await request(app)
          [method](url)
          .set("Authorization", `Bearer ${token}`);
        expect(res.status).toBe(403);
        expect(res.body.error.code).toBe("FORBIDDEN");
      }
    }
  });
});

describe("GET /api/admin/stats", () => {
  let adminToken;

  beforeAll(async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");
  });

  it("matches the database state exactly", async () => {
    await expectStatsMatchesDb(adminToken);
  });

  it("reflects the seeded data in the drivers and rides it counts", async () => {
    // Deliberately NO hardcoded minimums: the seed's upsert skips rows whose
    // values are unchanged (Sequelize emits no UPDATE), so on an aged test DB
    // seeded heartbeats/timestamps may legitimately lag. What must hold is
    // that the endpoint sees exactly what the database sees, and that the
    // seeded actors/rides are visible through the admin feed.
    const res = await get(adminToken, "/api/admin/stats");
    expect(res.status).toBe(200);
    expect(res.body.data.online_drivers).toBe(
      await Driver.count({ where: { online: true } }),
    );
    expect(res.body.data.completed_today).toBe(
      await Ride.count({
        where: { status: "completed", updated_at: { [Op.gte]: startOfToday() } },
      }),
    );

    const feed = await get(adminToken, "/api/admin/rides?status=completed");
    const addresses = feed.body.data.map((r) => r.pickup_address);
    expect(addresses).toContain("Central Market, Phnom Penh");
    expect(addresses).toContain("Sisowath Quay (Riverside), Phnom Penh");
  });

  it("exposes exactly the agreed KPI keys", async () => {
    const res = await get(adminToken, "/api/admin/stats");
    expect(Object.keys(res.body.data).sort()).toEqual(
      [
        "rides_today",
        "completed_today",
        "online_drivers",
        "avg_rating",
        "requested_now",
      ].sort(),
    );
    expect(typeof res.body.data.rides_today).toBe("number");
    expect(typeof res.body.data.online_drivers).toBe("number");
    expect(typeof res.body.data.requested_now).toBe("number");
  });
});

describe("GET /api/admin/drivers", () => {
  let adminToken;

  beforeAll(async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");
  });

  it("lists every driver with BOTH ids and the verification columns", async () => {
    const res = await get(adminToken, "/api/admin/drivers");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const byEmail = new Map(res.body.data.map((d) => [d.email, d]));
    for (const email of [
      "dara@taxi.demo",
      "sophea@taxi.demo",
      "vuthy@taxi.demo",
    ]) {
      expect(byEmail.has(email)).toBe(true);
    }

    // Vuthy: full shape check straight against the rows the seed wrote.
    const vuthyUser = await User.findOne({
      where: { email: "vuthy@taxi.demo" },
    });
    const vuthyRow = await Driver.findOne({ where: { user_id: vuthyUser.id } });
    expect(byEmail.get("vuthy@taxi.demo")).toEqual({
      driver_id: vuthyRow.id,
      user_id: vuthyUser.id,
      name: "Vuthy",
      email: "vuthy@taxi.demo",
      phone: vuthyUser.phone,
      rating: Number(vuthyUser.rating),
      active: true,
      price_per_km: Number(vuthyRow.price_per_km),
      verified: false,
      online: false,
    });

    // Seed flags for the two bookable drivers.
    expect(byEmail.get("dara@taxi.demo")).toMatchObject({
      verified: true,
      online: true,
      active: true,
    });
    expect(byEmail.get("sophea@taxi.demo")).toMatchObject({
      verified: true,
      online: true,
      active: true,
    });
  });

  it("rejects a malformed id with VALIDATION_ERROR (verify)", async () => {
    const res = await post(adminToken, "/api/admin/drivers/abc/verify");

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});

describe("POST /api/admin/drivers/:id/verify", () => {
  let adminToken;
  let vuthyDriverRowId;

  beforeAll(async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");
    const vuthyUser = await User.findOne({
      where: { email: "vuthy@taxi.demo" },
    });
    const row = await Driver.findOne({ where: { user_id: vuthyUser.id } });
    vuthyDriverRowId = row.id;
  });

  it("flips the unverified seeded driver to verified", async () => {
    const before = await Driver.findByPk(vuthyDriverRowId);
    expect(before.verified).toBe(false); // seed state

    const res = await post(
      adminToken,
      `/api/admin/drivers/${vuthyDriverRowId}/verify`,
    );

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      driver_id: vuthyDriverRowId,
      verified: true,
    });

    const after = await Driver.findByPk(vuthyDriverRowId);
    expect(after.verified).toBe(true);
  });

  it("is idempotent — verifying a verified driver stays verified", async () => {
    const res = await post(
      adminToken,
      `/api/admin/drivers/${vuthyDriverRowId}/verify`,
    );

    expect(res.status).toBe(200);
    expect(res.body.data.verified).toBe(true);
  });

  it("returns NOT_FOUND for an unknown driver id", async () => {
    const res = await post(adminToken, "/api/admin/drivers/999999/verify");

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });
});

describe("POST /api/admin/drivers/:id/suspend", () => {
  let adminToken;
  let freshCustomerToken;
  let suspDriverRowId;

  beforeAll(async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");

    // Dedicated actor (location-heartbeat convention): verified + online +
    // fresh, but owned by THIS suite — suspending a SHARED seed driver would
    // race suites in parallel workers that legitimately book dara/sophea.
    const suspEmail = `${Date.now()}-admin-suspend-driver@test.demo`;
    suspendFixtureEmails.push(suspEmail);
    const suspUser = await User.create({
      role: "driver",
      name: "Suspend Target",
      phone: "012345681",
      email: suspEmail,
      password_hash: "not-a-real-login",
    });
    suspDriverRow = await Driver.create({
      user_id: suspUser.id,
      car_model: "Honda Dream",
      plate: "PP-9Z-9999",
      license_no: "KH-DL-9999",
      verified: true,
      online: true,
      price_per_km: "1.00",
      lat: "11.5580000",
      lng: "104.9290000",
      updated_at: new Date(),
    });
    suspDriverRowId = suspDriverRow.id;
    suspDriverUserId = suspUser.id;

    // Fresh per-run customer (nearby.test convention): the booking attempt
    // below must fail on SUSPENSION, never on a leftover RIDE_BUSY_CUSTOMER
    // from a crashed earlier run in this shared test database.
    const custEmail = `${Date.now()}-admin-suspend@test.demo`;
    suspendFixtureEmails.push(custEmail);
    const reg = await request(app).post("/api/register").send({
      name: "Admin Suite Customer",
      phone: "012345679",
      email: custEmail,
      password: "Password1",
    });
    expect(reg.status).toBe(201);
    fixtureEmail = reg.body.data.user.email;
    freshCustomerToken = reg.body.data.token;
  });

  it("sets users.active=false and reports it", async () => {
    const res = await post(
      adminToken,
      `/api/admin/drivers/${suspDriverRowId}/suspend`,
    );

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      driver_id: suspDriverRowId,
      user_id: expect.any(Number),
      active: false,
    });

    const userAfter = await User.findByPk(suspDriverUserId);
    expect(userAfter.active).toBe(false);
  });

  it("makes the suspended driver unbookable even though verified+online (FORBIDDEN)", async () => {
    const res = await post(
      freshCustomerToken,
      "/api/rides",
      bookingBody(suspDriverRowId, "suspended"),
    );

    // §2 invariant (Task 6.1): suspension blocks future requests — the task
    // text reuses FORBIDDEN for it, checked BEFORE the busy-driver checks.
    // The target passes every deck filter, so ONLY the suspension explains it.
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");

    // The refusal left no ride row behind.
    const leftovers = await Ride.findAll({
      where: { pickup_address: "[admin-test] pickup suspended" },
    });
    expect(leftovers).toEqual([]);
  });

  it("blocks the suspended driver from going back online (FORBIDDEN)", async () => {
    const { signToken } = await import("../src/utils/jwt.js");
    const token = signToken({ id: suspDriverUserId, role: "driver" });
    const res = await patch(token, "/api/drivers/online", { online: true });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("still allows a suspended driver to go OFFLINE", async () => {
    const { signToken } = await import("../src/utils/jwt.js");
    const token = signToken({ id: suspDriverUserId, role: "driver" });
    const res = await patch(token, "/api/drivers/online", {
      online: false,
    });

    expect(res.status).toBe(200);
  });

  it("returns NOT_FOUND for an unknown driver id", async () => {
    const res = await post(adminToken, "/api/admin/drivers/999999/suspend");

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });
});

describe("GET /api/admin/rides", () => {
  let adminToken;

  beforeAll(async () => {
    adminToken = await login("admin@taxi.demo", "Admin@123");
  });

  it("lists rides newest-first with party snapshots", async () => {
    const res = await get(adminToken, "/api/admin/rides");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);

    const rows = res.body.data;
    for (let i = 1; i < rows.length; i++) {
      const prev = rows[i - 1];
      const cur = rows[i];
      const newer =
        prev.created_at > cur.created_at ||
        (prev.created_at === cur.created_at && prev.id > cur.id);
      expect(newer).toBe(true); // created_at DESC, id DESC tie-break

      expect(rows[i - 1].customer).toMatchObject({
        id: rows[i - 1].customer_id,
        name: expect.any(String),
      });
      expect(rows[i - 1].driver).toMatchObject({ id: rows[i - 1].driver_id });
    }
  });

  it("contains the two seeded completed rides with honest history", async () => {
    const res = await get(adminToken, "/api/admin/rides");

    const central = res.body.data.find(
      (r) => r.pickup_address === "Central Market, Phnom Penh",
    );
    const riverside = res.body.data.find(
      (r) => r.pickup_address === "Sisowath Quay (Riverside), Phnom Penh",
    );

    expect(central).toMatchObject({ status: "completed" });
    expect(central.driver.name).toBe("Dara");
    expect(riverside).toMatchObject({ status: "completed" });
    expect(riverside.driver.name).toBe("Sophea");
  });

  it("filters by ?status=completed", async () => {
    const res = await get(adminToken, "/api/admin/rides?status=completed");

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThan(0);
    for (const ride of res.body.data) {
      expect(ride.status).toBe("completed");
    }
    const addresses = res.body.data.map((r) => r.pickup_address);
    expect(addresses).toContain("Central Market, Phnom Penh");
    expect(addresses).toContain("Sisowath Quay (Riverside), Phnom Penh");
  });

  it("filters by ?status=requested without inventing rows", async () => {
    const res = await get(adminToken, "/api/admin/rides?status=requested");

    expect(res.status).toBe(200);
    for (const ride of res.body.data) {
      expect(ride.status).toBe("requested");
    }
  });

  it("rejects an unknown status with VALIDATION_ERROR", async () => {
    const res = await get(adminToken, "/api/admin/rides?status=flying");

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});
