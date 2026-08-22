import { execSync } from "node:child_process";
import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";

// Task 4.3 — the state machine reachable over REST (ARCHITECTURE §2 + §4).
//
// Isolation: this suite runs against motodub_test, NOT the dev database —
// completed rides and rating changes would corrupt demo data otherwise.
// DB_NAME must be set BEFORE the dynamic imports below resolve
// config/db.js (a static import would hoist above this line and bind the
// dev database instead). The env override is restored in afterAll so any
// sibling suite sharing this jest worker keeps its dev-DB convention.
const ORIGINAL_DB_NAME = process.env.DB_NAME;
process.env.DB_NAME = "motodub_test";

const MARKER = "[ride-flow-test]";

let sequelize;
let User;
let Driver;
let Ride;
let app;

async function login(email, password) {
  const res = await request(app).post("/api/login").send({ email, password });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

// supertest v7: request(app) exposes only method shortcuts — the bearer
// header goes on the Test returned by the method call, never before it.
async function post(token, url, body) {
  const req = request(app).post(url).set("Authorization", `Bearer ${token}`);
  return body === undefined ? await req : await req.send(body);
}

function get(token, url) {
  return request(app).get(url).set("Authorization", `Bearer ${token}`);
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

// Prior-based average (state-machine.test convention): derives the expected
// users.rating from the rows that exist BEFORE acting, so reruns stay honest.
async function expectedRatingAfter(targetUserId, fkColumn, receivedColumn, added) {
  const [row] = await Ride.findAll({
    attributes: [
      [sequelize.fn("AVG", sequelize.col(receivedColumn)), "avg"],
      [sequelize.fn("COUNT", sequelize.col(receivedColumn)), "n"],
    ],
    where: { [fkColumn]: targetUserId, [receivedColumn]: { [Op.ne]: null } },
    raw: true,
  });
  const n = Number(row.n);
  const sum = n > 0 ? parseFloat(row.avg) * n : 0;
  return Math.round(((sum + added) / (n + 1)) * 10) / 10;
}

beforeAll(async () => {
  await import("dotenv/config");
  // Shell/env value above wins — dotenv never overrides existing variables.

  // Self-bootstrapping test setup (IMPLEMENTATION 4.3 verify): create,
  // migrate and seed motodub_test through the project's own tooling.
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

  // Idempotent start: a crashed earlier run may have left MARKER rides that
  // block srey with RIDE_BUSY_CUSTOMER. The test DB is disposable — drop them.
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
  });
});

afterAll(async () => {
  if (sequelize) await sequelize.close();
  process.env.DB_NAME = ORIGINAL_DB_NAME;
});

describe("POST /api/rides gates", () => {
  it("rejects an unauthenticated request with UNAUTHORIZED", async () => {
    const res = await request(app)
      .post("/api/rides")
      .send(bookingBody(1, "gate"));

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("rejects a driver token with FORBIDDEN (§4 matrix)", async () => {
    const daraToken = await login("dara@taxi.demo", "Demo@123");
    const res = await post(
      daraToken,
      "/api/rides",
      bookingBody(1, "gate"),
    );

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });
});

describe("happy path — srey books dara, full lifecycle, both rate", () => {
  let sreyToken;
  let daraToken;
  let sopheaToken;
  let vithyToken;
  let adminToken;
  let srey;
  let dara;
  let daraDriverRowId;
  let rideId;

  beforeAll(async () => {
    sreyToken = await login("srey@taxi.demo", "Demo@123");
    daraToken = await login("dara@taxi.demo", "Demo@123");
    sopheaToken = await login("sophea@taxi.demo", "Demo@123");
    vithyToken = await login("vithy@taxi.demo", "Demo@123");
    adminToken = await login("admin@taxi.demo", "Admin@123");

    srey = await User.findOne({ where: { email: "srey@taxi.demo" } });
    dara = await User.findOne({ where: { email: "dara@taxi.demo" } });
    const daraDriver = await Driver.findOne({ where: { user_id: dara.id } });
    daraDriverRowId = daraDriver.id;
  });

  it("creates a requested ride", async () => {
    const res = await post(
      sreyToken,
      "/api/rides",
      bookingBody(daraDriverRowId, "happy"),
    );

    expect(res.status).toBe(201);
    rideId = res.body.data.id;
    expect(res.body.data).toMatchObject({
      customer_id: srey.id,
      driver_id: dara.id,
      status: "requested",
    });

    // Never-set columns read back NULL from the ROW, not off the fresh
    // create instance (ride-create.test convention) — §9 fare stays NULL.
    const row = await Ride.findByPk(rideId);
    expect(row.fare).toBeNull();
    expect(row.customer_rating).toBeNull();
    expect(row.driver_rating).toBeNull();
  });

  it("blocks a stranger driver from accepting (FORBIDDEN)", async () => {
    const res = await post(sopheaToken, `/api/rides/${rideId}/accept`);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("accept transitions requested → accepted (the ride's driver)", async () => {
    const res = await post(daraToken, `/api/rides/${rideId}/accept`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe("accepted");
  });

  it("start transitions accepted → en_route", async () => {
    const res = await post(daraToken, `/api/rides/${rideId}/start`);

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("en_route");
  });

  it("start-ride transitions en_route → in_progress", async () => {
    const res = await post(daraToken, `/api/rides/${rideId}/start-ride`);

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("in_progress");
  });

  it("complete transitions in_progress → completed", async () => {
    const res = await post(daraToken, `/api/rides/${rideId}/complete`);

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("completed");
  });

  it("hides the ride from non-participants, shows it to admin (§4)", async () => {
    const stranger = await get(vithyToken, `/api/rides/${rideId}`);
    expect(stranger.status).toBe(403);
    expect(stranger.body.error.code).toBe("FORBIDDEN");

    const participant = await get(sreyToken, `/api/rides/${rideId}`);
    expect(participant.status).toBe(200);
    expect(participant.body.data.id).toBe(rideId);

    const admin = await get(adminToken, `/api/rides/${rideId}`);
    expect(admin.status).toBe(200);
    expect(admin.body.data.id).toBe(rideId);
  });

  it("carries the customer name/rating summary for the driver's request card", async () => {
    const res = await get(daraToken, `/api/rides/${rideId}`);

    expect(res.status).toBe(200);
    expect(res.body.data.customer).toMatchObject({
      id: srey.id,
      name: srey.name,
    });
    expect(res.body.data.customer.rating).toBeDefined();
  });

  // Task 5.1: the tracking screen's driver info card needs car, plate and
  // phone — none of which live on the ride row itself.
  it("carries the driver car/phone snapshot for the customer's tracking screen", async () => {
    const daraDriver = await Driver.findOne({ where: { user_id: dara.id } });
    const res = await get(sreyToken, `/api/rides/${rideId}`);

    expect(res.status).toBe(200);
    expect(res.body.data.driver).toMatchObject({
      id: dara.id,
      name: dara.name,
      phone: dara.phone,
      car_model: daraDriver.car_model,
      plate: daraDriver.plate,
    });
    // users.rating is DECIMAL — serialized as a string ("5.0").
    expect(parseFloat(res.body.data.driver.rating)).toBe(Number(dara.rating));
  });

  it("rejects stars outside 1–5 with VALIDATION_ERROR", async () => {
    const res = await post(sreyToken, `/api/rides/${rideId}/rate`, {
      stars: 6,
    });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("denies a non-participant rating (admin → FORBIDDEN)", async () => {
    const res = await post(adminToken, `/api/rides/${rideId}/rate`, {
      stars: 5,
    });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("customer rates the driver; the driver's average updates", async () => {
    const expected = await expectedRatingAfter(
      dara.id,
      "driver_id",
      "customer_rating",
      5,
    );

    const res = await post(sreyToken, `/api/rides/${rideId}/rate`, {
      stars: 5,
    });

    expect(res.status).toBe(200);
    expect(res.body.data.customer_rating).toBe(5);

    const daraAfter = await User.findByPk(dara.id);
    expect(Number(daraAfter.rating)).toBe(expected);
  });

  it("driver rates the customer; the customer's average updates", async () => {
    const expected = await expectedRatingAfter(
      srey.id,
      "customer_id",
      "driver_rating",
      4,
    );

    const res = await post(daraToken, `/api/rides/${rideId}/rate`, {
      stars: 4,
    });

    expect(res.status).toBe(200);
    expect(res.body.data.driver_rating).toBe(4);

    const sreyAfter = await User.findByPk(srey.id);
    expect(Number(sreyAfter.rating)).toBe(expected);
  });

  it("rating twice fails (RIDE_INVALID_TRANSITION)", async () => {
    const res = await post(sreyToken, `/api/rides/${rideId}/rate`, {
      stars: 3,
    });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("RIDE_INVALID_TRANSITION");
  });
});

describe("decline path — srey books sophea", () => {
  let sreyToken;
  let sopheaToken;
  let sopheaDriverRowId;
  let rideId;

  beforeAll(async () => {
    sreyToken = await login("srey@taxi.demo", "Demo@123");
    sopheaToken = await login("sophea@taxi.demo", "Demo@123");
    const sophea = await User.findOne({ where: { email: "sophea@taxi.demo" } });
    const row = await Driver.findOne({ where: { user_id: sophea.id } });
    sopheaDriverRowId = row.id;
  });

  it("decline transitions requested → declined", async () => {
    const created = await post(
      sreyToken,
      "/api/rides",
      bookingBody(sopheaDriverRowId, "declined"),
    );
    expect(created.status).toBe(201);
    rideId = created.body.data.id;

    const res = await post(sopheaToken, `/api/rides/${rideId}/decline`);

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("declined");
  });

  it("cannot accept a declined ride (RIDE_INVALID_TRANSITION)", async () => {
    const res = await post(sopheaToken, `/api/rides/${rideId}/accept`);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("RIDE_INVALID_TRANSITION");
  });
});

describe("cancel path — customer cancels a requested ride", () => {
  let sreyToken;
  let daraToken;
  let daraDriverRowId;
  let rideId;

  beforeAll(async () => {
    sreyToken = await login("srey@taxi.demo", "Demo@123");
    daraToken = await login("dara@taxi.demo", "Demo@123");
    const dara = await User.findOne({ where: { email: "dara@taxi.demo" } });
    const row = await Driver.findOne({ where: { user_id: dara.id } });
    daraDriverRowId = row.id;
  });

  it("driver cannot cancel a merely-requested ride (RIDE_INVALID_TRANSITION)", async () => {
    const created = await post(
      sreyToken,
      "/api/rides",
      bookingBody(daraDriverRowId, "cancel"),
    );
    expect(created.status).toBe(201);
    rideId = created.body.data.id;

    const res = await post(daraToken, `/api/rides/${rideId}/cancel`);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("RIDE_INVALID_TRANSITION");
  });

  it("customer cancels their own requested ride", async () => {
    const res = await post(sreyToken, `/api/rides/${rideId}/cancel`);

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("cancelled");
  });
});

describe("GET /api/rides/mine", () => {
  let sreyToken;
  let daraToken;
  let vithyToken;
  let adminToken;

  beforeAll(async () => {
    sreyToken = await login("srey@taxi.demo", "Demo@123");
    daraToken = await login("dara@taxi.demo", "Demo@123");
    vithyToken = await login("vithy@taxi.demo", "Demo@123");
    adminToken = await login("admin@taxi.demo", "Admin@123");
  });

  it("requires authentication", async () => {
    const res = await request(app).get("/api/rides/mine");

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("lists srey's rides newest-first (role-scoped)", async () => {
    const res = await get(sreyToken, "/api/rides/mine");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const ids = res.body.data.map((r) => r.id);
    expect(ids.length).toBeGreaterThan(0);
    expect([...ids].sort((a, b) => b - a)).toEqual(ids); // newest first

    const mine = await User.findOne({ where: { email: "srey@taxi.demo" } });
    for (const ride of res.body.data) {
      expect(ride.customer_id).toBe(mine.id);

      // Task 5.2: history rows carry timestamps + the opposite-party
      // snapshot — customer view → driver name/rating + car/plate.
      expect(ride.created_at).toBeTruthy();
      expect(ride.updated_at).toBeTruthy();
      expect(ride.driver).toMatchObject({
        id: ride.driver_id,
        car_model: expect.any(String),
        plate: expect.any(String),
      });
      expect(typeof ride.driver.name).toBe("string");
      // DECIMAL serializes as string ("4.5") — parseable either way.
      expect(Number(ride.driver.rating)).not.toBeNaN();
    }

    // Seeded history: srey rode with dara AND sophea — both snapshots present.
    const driverNames = res.body.data.map((r) => r.driver.name);
    expect(driverNames).toContain("Dara");
    expect(driverNames).toContain("Sophea");
  });

  it("lists dara's driver-side rides", async () => {
    const res = await get(daraToken, "/api/rides/mine");

    expect(res.status).toBe(200);
    const daraUser = await User.findOne({ where: { email: "dara@taxi.demo" } });
    expect(res.body.data.length).toBeGreaterThan(0);
    for (const ride of res.body.data) {
      expect(ride.driver_id).toBe(daraUser.id);

      // Task 5.2: driver view → customer name/rating + timestamps.
      expect(ride.created_at).toBeTruthy();
      expect(ride.updated_at).toBeTruthy();
      expect(ride.customer).toMatchObject({ id: ride.customer_id });
      expect(typeof ride.customer.name).toBe("string");
      // DECIMAL serializes as string ("4.5") — parseable either way.
      expect(Number(ride.customer.rating)).not.toBeNaN();
    }

    // Seeded completed ride: srey was the customer.
    expect(res.body.data.map((r) => r.customer.name)).toContain("Srey");
  });

  it("never leaks another customer's rides", async () => {
    const sreyRes = await get(sreyToken, "/api/rides/mine");
    const vithyRes = await get(vithyToken, "/api/rides/mine");

    const sreyIds = sreyRes.body.data.map((r) => r.id);
    const vithyIds = vithyRes.body.data.map((r) => r.id);
    for (const id of sreyIds) {
      expect(vithyIds).not.toContain(id);
    }
  });

  it("gives an admin an empty scope (never a ride participant)", async () => {
    const res = await get(adminToken, "/api/rides/mine");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual([]);
  });
});
