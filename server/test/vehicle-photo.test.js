import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import fs from "node:fs";
import path from "node:path";
import { Op } from "sequelize";
import { signToken } from "../src/utils/jwt.js";
import { User, Driver, Ride } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

// Task: POST /api/drivers/vehicle-photo — driver-only multipart upload that
// stores a uuid-named image under /uploads and records drivers.vehicle_photo.
// Same acceptance rules as POST /api/users/me/avatar (jpeg/png/webp ≤ 5MB).
//
// Isolation: dev database like profile.test.js / nearby.test.js — every
// actor is a unique per-run fixture destroyed in afterAll.

const app = createApp();
const uploadsDir = path.resolve(process.cwd(), "uploads");

// 1x1 PNG, in memory (profile.test.js convention).
const TINY_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

let driverToken;
let customerToken;
let driverUserId;
const fixtureEmails = [];
const uploadedFiles = [];

function authed(req) {
  return req.set("Authorization", `Bearer ${driverToken}`);
}

beforeAll(async () => {
  await sequelize.authenticate();

  // Unique driver fixture (User.create + Driver row, nearby busy-driver style).
  const driverEmail = `${Date.now()}-vehphoto-driver@test.demo`;
  fixtureEmails.push(driverEmail);
  const driverUser = await User.create({
    role: "driver",
    name: "Photo Pich",
    phone: "012777888",
    email: driverEmail,
    password_hash: "not-a-real-login",
  });
  driverUserId = driverUser.id;
  await Driver.create({
    user_id: driverUser.id,
    car_model: "Honda Vision scooter",
    plate: "PP-7F-7777",
    license_no: "KH-DL-7777",
    verified: false,
    online: false,
    price_per_km: "1.10",
    lat: "11.5564000",
    lng: "104.9282000",
    updated_at: new Date(),
  });
  driverToken = signToken({ id: driverUser.id, role: "driver" });

  // Unique customer for the RBAC gate and the nearby read.
  const custEmail = `${Date.now()}-vehphoto-cust@test.demo`;
  fixtureEmails.push(custEmail);
  const reg = await request(app).post("/api/register").send({
    name: "Vehicle Vera",
    phone: "012345678",
    email: custEmail,
    password: "Password1",
  });
  expect(reg.status).toBe(201);
  customerToken = reg.body.data.token;
});

afterAll(async () => {
  // Uploaded bytes must not survive the suite.
  for (const name of uploadedFiles) {
    fs.rmSync(path.join(uploadsDir, name), { force: true });
  }
  // FK order: rides → drivers → users (no rides here).
  if (driverUserId) await Driver.destroy({ where: { user_id: driverUserId } });
  await User.destroy({ where: { email: { [Op.in]: fixtureEmails } } });
  await sequelize.close();
});

describe("POST /api/drivers/vehicle-photo", () => {
  it("rejects an unauthenticated caller with UNAUTHORIZED", async () => {
    const res = await request(app)
      .post("/api/drivers/vehicle-photo")
      .attach("photo", TINY_PNG, "bike.png");

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("rejects a customer token with FORBIDDEN", async () => {
    const res = await request(app)
      .post("/api/drivers/vehicle-photo")
      .set("Authorization", `Bearer ${customerToken}`)
      .attach("photo", TINY_PNG, "bike.png");

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("stores a jpeg/png/webp upload under /uploads and returns the updated "
      + "driver incl. vehicle_photo", async () => {
    const res = await authed(request(app).post("/api/drivers/vehicle-photo"))
      .attach("photo", TINY_PNG, { filename: "bike.png", contentType: "image/png" });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const url = res.body.data.vehicle_photo;
    expect(url).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);

    const onDisk = path.join(uploadsDir, path.basename(url));
    expect(fs.existsSync(onDisk)).toBe(true);
    uploadedFiles.push(path.basename(url));

    // Updated driver shape keeps the vehicle fields around the new column.
    expect(res.body.data).toMatchObject({
      car_model: "Honda Vision scooter",
      plate: "PP-7F-7777",
    });

    // The column itself persisted.
    const row = await Driver.findOne({ where: { user_id: driverUserId } });
    expect(row.vehicle_photo).toBe(url);
  });

  it("rejects a non-image upload with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).post("/api/drivers/vehicle-photo"))
      .attach("photo", Buffer.from("not an image"), {
        filename: "note.txt",
        contentType: "text/plain",
      });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("surfaces vehicle_photo on GET /api/drivers/me after an upload", async () => {
    const me = await authed(request(app).get("/api/drivers/me"));
    expect(me.status).toBe(200);
    expect(me.body.data.vehicle_photo).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);
  });
});

describe("GET /api/drivers/nearby carries vehicle_photo", () => {
  const PP_CENTER = { lat: 11.5564, lng: 104.9282 };

  it("includes vehicle_photo on every deck card — the uploaded URL for our "
      + "fixture once visible, null for drivers without one", async () => {
    // Make the fixture pass the §8 deck filter (verified+online+fresh+close).
    await Driver.update(
      { verified: true, online: true, updated_at: new Date() },
      { where: { user_id: driverUserId } },
    );

    const res = await request(app)
      .get("/api/drivers/nearby")
      .query(PP_CENTER)
      .set("Authorization", `Bearer ${customerToken}`);

    expect(res.status).toBe(200);
    const cards = res.body.data;
    expect(cards.length).toBeGreaterThan(0);
    for (const card of cards) {
      expect(card).toHaveProperty("vehicle_photo");
    }

    const mine = cards.find((c) => c.plate === "PP-7F-7777");
    expect(mine).toBeDefined();
    expect(mine.vehicle_photo).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);

    // Restore canonical flags so sibling suites see the seeded world.
    await Driver.update(
      { verified: false, online: false },
      { where: { user_id: driverUserId } },
    );
  });
});
