import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";
import { signToken } from "../src/utils/jwt.js";
import { User, Driver, Ride } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

const app = createApp();
const PP_CENTER = { lat: 11.5564, lng: 104.9282 };
const MARKER = "[nearby-test]"; // identifies fixture rides for cleanup

let customerToken;
let busyUserId;
const fixtureEmails = [];

async function cleanupFixtures() {
  // FK order: rides → drivers → users
  await Ride.destroy({ where: { pickup_address: MARKER } });
  if (busyUserId) await Driver.destroy({ where: { user_id: busyUserId } });
  await User.destroy({ where: { email: { [Op.in]: fixtureEmails } } });
}

beforeAll(async () => {
  await sequelize.authenticate();

  // The 15s heartbeat window makes updated_at time-sensitive between seed
  // run and test run — re-freshen heartbeats and restore canonical flags so
  // this suite is independent of when `npm run seed` last ran.
  for (const s of [
    { email: "dara@taxi.demo", verified: true, online: true },
    { email: "sophea@taxi.demo", verified: true, online: true },
    { email: "vuthy@taxi.demo", verified: false, online: false },
  ]) {
    const user = await User.findOne({ where: { email: s.email } });
    await Driver.update(
      { verified: s.verified, online: s.online, updated_at: new Date() },
      { where: { user_id: user.id } },
    );
  }

  // Unique per-run customer (auth.test convention) for the Authorization header.
  const custEmail = `${Date.now()}-nearby-cust@test.demo`;
  fixtureEmails.push(custEmail);
  const reg = await request(app).post("/api/register").send({
    name: "Nearby Customer",
    phone: "012345678",
    email: custEmail,
    password: "Password1",
  });
  expect(reg.status).toBe(201);
  customerToken = reg.body.data.token;
  const customer = await User.findOne({ where: { email: custEmail } });

  // Busy-driver fixture: verified + online + fresh + near PP center, but
  // holding an ACTIVE ride — must be excluded despite passing every filter.
  const busyEmail = `${Date.now()}-nearby-busy@test.demo`;
  fixtureEmails.push(busyEmail);
  const busyUser = await User.create({
    role: "driver",
    name: "Busy Bona",
    phone: "012999999",
    email: busyEmail,
    password_hash: "not-a-real-login",
  });
  busyUserId = busyUser.id;
  await Driver.create({
    user_id: busyUser.id,
    car_model: "Toyota Prius hatchback",
    plate: "PP-9Z-9999",
    license_no: "KH-DL-9999",
    verified: true,
    online: true,
    price_per_km: "1.00",
    lat: "11.5580000",
    lng: "104.9290000",
    updated_at: new Date(),
  });
  await Ride.create({
    customer_id: customer.id,
    driver_id: busyUser.id,
    status: "requested",
    pickup_lat: "11.5564000",
    pickup_lng: "104.9282000",
    pickup_address: MARKER,
    dropoff_lat: "11.5484000",
    dropoff_lng: "104.8928000",
    dropoff_address: MARKER,
  });
});

afterAll(async () => {
  await cleanupFixtures();
  await sequelize.close();
});

function getNearby(query = PP_CENTER) {
  return request(app)
    .get("/api/drivers/nearby")
    .query(query)
    .set("Authorization", `Bearer ${customerToken}`);
}

describe("GET /api/drivers/nearby", () => {
  it("returns seeded available drivers sorted by distance for a PP-center query", async () => {
    const res = await getNearby();

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const cards = res.body.data;
    const names = cards.map((c) => c.name);
    expect(names).toContain("Dara");
    expect(names).toContain("Sophea");

    // closest first. Distance 0 is legitimate — demo heartbeats can pin a
    // driver exactly on the query point, so only the radius is a hard cap.
    const distances = cards.map((c) => c.distance_km);
    expect(distances).toEqual([...distances].sort((a, b) => a - b));
    for (const d of distances) {
      expect(d).toBeGreaterThanOrEqual(0);
      expect(d).toBeLessThanOrEqual(10);
    }
  });

  it("returns every §4 card field with API-friendly types", async () => {
    const res = await getNearby();

    expect(res.status).toBe(200);
    const card = res.body.data[0];
    expect(card).toMatchObject({
      id: expect.any(Number),
      name: expect.any(String),
      rating: expect.any(Number),
      car_model: expect.any(String),
      plate: expect.any(String),
      price_per_km: expect.any(Number),
      distance_km: expect.any(Number),
      eta_minutes: expect.any(Number),
    });
    // Demo activity can attach an avatar to any seeded user; the API
    // contract is "URL string or null", not a specific value.
    expect(card.photo === null || typeof card.photo === "string").toBe(true);
  });

  it("excludes unverified/offline drivers (Vuthy)", async () => {
    const res = await getNearby();

    expect(res.status).toBe(200);
    expect(res.body.data.map((c) => c.name)).not.toContain("Vuthy");
  });

  it("excludes a verified+online driver holding an active ride", async () => {
    const res = await getNearby();

    expect(res.status).toBe(200);
    expect(res.body.data.map((c) => c.name)).not.toContain("Busy Bona");
  });

  it("rejects missing lat with VALIDATION_ERROR", async () => {
    const res = await getNearby({ lng: PP_CENTER.lng });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects a non-numeric lng with VALIDATION_ERROR", async () => {
    const res = await getNearby({ ...PP_CENTER, lng: "far-away" });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("is customer-only — driver tokens get 403 FORBIDDEN", async () => {
    const token = signToken({ id: busyUserId, role: "driver" });
    const res = await request(app)
      .get("/api/drivers/nearby")
      .query(PP_CENTER)
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });
});
