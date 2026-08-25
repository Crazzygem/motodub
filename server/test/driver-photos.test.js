import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import fs from "node:fs";
import path from "node:path";
import { Op } from "sequelize";
import { signToken } from "../src/utils/jwt.js";
import { User, Driver } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

// Multi-photo driver card: POST /api/drivers/photos (append, cap 6, cover
// sync) + DELETE /api/drivers/photos ({index}, unlink best-effort) and the
// vehicle_photos array riding on every deck-card payload — including the
// legacy fall back to the single vehicle_photo cover.
//
// Isolation: dev database like vehicle-photo.test.js — every actor is a
// unique per-run fixture destroyed in afterAll.

const app = createApp();
const uploadsDir = path.resolve(process.cwd(), "uploads");

// 1x1 PNG, in memory (profile.test.js convention).
const TINY_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

let galleryToken;
let customerToken;
let galleryUserId;
let legacyUserId;
const fixtureEmails = [];
const uploadedFiles = [];

function authed(req) {
  return req.set("Authorization", `Bearer ${galleryToken}`);
}

function uploadPhotos(req, count) {
  let multipart = req.attach("photos", TINY_PNG, {
    filename: "a.png",
    contentType: "image/png",
  });
  for (let i = 1; i < count; i += 1) {
    multipart = multipart.attach("photos", TINY_PNG, {
      filename: `b${i}.png`,
      contentType: "image/png",
    });
  }
  return multipart;
}

beforeAll(async () => {
  await sequelize.authenticate();

  // Driver A: pre-column legacy row — a cover but NO gallery array yet.
  const run = Date.now();
  const galleryEmail = `${run}-gallery-driver@test.demo`;
  fixtureEmails.push(galleryEmail);
  const galleryUser = await User.create({
    role: "driver",
    name: "Gallery Gana",
    phone: "012555000",
    email: galleryEmail,
    password_hash: "not-a-real-login",
  });
  galleryUserId = galleryUser.id;
  await Driver.create({
    user_id: galleryUser.id,
    car_model: "Honda Vision scooter",
    plate: "PP-5G-0001",
    license_no: "KH-DL-5001",
    verified: false,
    online: false,
    price_per_km: "1.10",
    lat: "11.5564000",
    lng: "104.9282000",
    updated_at: new Date(),
    vehicle_photo: `/uploads/legacy-cover-${run}.png`,
  });
  galleryToken = signToken({ id: galleryUser.id, role: "driver" });

  // Driver B: another legacy-only row for the payload fallback check.
  const legacyEmail = `${run}-legacy-driver@test.demo`;
  fixtureEmails.push(legacyEmail);
  const legacyUser = await User.create({
    role: "driver",
    name: "Legacy Lida",
    phone: "012555111",
    email: legacyEmail,
    password_hash: "not-a-real-login",
  });
  legacyUserId = legacyUser.id;
  await Driver.create({
    user_id: legacyUser.id,
    car_model: "Yamaha Sirius",
    plate: "PP-5G-0002",
    license_no: "KH-DL-5002",
    verified: false,
    online: false,
    price_per_km: "1.00",
    lat: "11.5500000",
    lng: "104.9200000",
    updated_at: new Date(),
    vehicle_photo: `/uploads/legacy-only-${run}.png`,
  });

  const custEmail = `${run}-gallery-cust@test.demo`;
  fixtureEmails.push(custEmail);
  const reg = await request(app).post("/api/register").send({
    name: "Gallery Gus",
    phone: "012999888",
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
  // FK order: drivers → users.
  await Driver.destroy({ where: { user_id: { [Op.in]: [galleryUserId, legacyUserId].filter(Boolean) } } });
  await User.destroy({ where: { email: { [Op.in]: fixtureEmails } } });
  await sequelize.close();
});

async function rowOf(userId) {
  return Driver.findOne({ where: { user_id: userId } });
}

describe("POST /api/drivers/photos", () => {
  it("rejects an unauthenticated caller with UNAUTHORIZED", async () => {
    const res = await uploadPhotos(
      request(app).post("/api/drivers/photos"),
      1,
    );
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("rejects a customer token with FORBIDDEN", async () => {
    const res = await uploadPhotos(
      request(app)
        .post("/api/drivers/photos")
        .set("Authorization", `Bearer ${customerToken}`),
      1,
    );
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("APPENDS to the legacy cover and keeps it as the synced first element", async () => {
    const before = await rowOf(galleryUserId);
    const legacyCover = before.vehicle_photo;

    const res = await uploadPhotos(authed(request(app).post("/api/drivers/photos")), 3);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const photos = res.body.data.vehicle_photos;
    expect(photos).toHaveLength(4);
    expect(photos[0]).toBe(legacyCover);
    for (const url of photos.slice(1)) {
      expect(url).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);
      uploadedFiles.push(path.basename(url));
    }

    // Cover invariant: still the first element — untouched legacy photo.
    expect(res.body.data.vehicle_photo).toBe(legacyCover);

    // Persisted as the JSON array; /me reads the decoded array back.
    const row = await rowOf(galleryUserId);
    expect(row.vehicle_photos).toEqual(photos);
    const me = await authed(request(app).get("/api/drivers/me"));
    expect(me.status).toBe(200);
    expect(me.body.data.vehicle_photos).toEqual(photos);
  });

  it("rejects a batch that would push the gallery past 6 and changes nothing", async () => {
    const before = await rowOf(galleryUserId);
    const frozen = [...before.vehicle_photos];

    // 4 stored + 3 incoming = 7 > 6.
    const res = await uploadPhotos(authed(request(app).post("/api/drivers/photos")), 3);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");

    const after = await rowOf(galleryUserId);
    expect(after.vehicle_photos).toEqual(frozen);
  });

  it("rejects a non-image attachment with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).post("/api/drivers/photos"))
      .attach("photos", Buffer.from("still not an image"), {
        filename: "note.txt",
        contentType: "text/plain",
      });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});

describe("DELETE /api/drivers/photos", () => {
  it("rejects an out-of-range index with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).delete("/api/drivers/photos"))
      .send({ index: 99 });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects a negative index with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).delete("/api/drivers/photos"))
      .send({ index: -1 });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("removes the indexed photo, unlinks its file, keeps the order", async () => {
    const before = await rowOf(galleryUserId);
    const doomed = before.vehicle_photos[1];

    const res = await authed(request(app).delete("/api/drivers/photos"))
      .send({ index: 1 });

    expect(res.status).toBe(200);
    expect(res.body.data.vehicle_photos).toEqual(
      before.vehicle_photos.filter((url) => url !== doomed),
    );
    expect(fs.existsSync(path.join(uploadsDir, path.basename(doomed))))
      .toBe(false);

    // Cover untouched — the removed photo was not the first element.
    expect(res.body.data.vehicle_photo).toBe(before.vehicle_photo);
  });

  it("re-syncs the cover to the new first element when index 0 goes away", async () => {
    const res = await authed(request(app).delete("/api/drivers/photos"))
      .send({ index: 0 });

    expect(res.status).toBe(200);
    const photos = res.body.data.vehicle_photos;
    expect(photos.length).toBeGreaterThan(0);
    // The legacy fake cover is gone; the real first upload takes over.
    expect(res.body.data.vehicle_photo).toBe(photos[0]);
    expect(photos[0]).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);
  });

  it("clears the cover once the gallery empties", async () => {
    let res = await authed(request(app).delete("/api/drivers/photos"))
      .send({ index: 0 });
    expect(res.status).toBe(200);
    const lastUrl = res.body.data.vehicle_photos[0];
    uploadedFiles.push(path.basename(lastUrl));

    res = await authed(request(app).delete("/api/drivers/photos"))
      .send({ index: 0 });
    expect(res.status).toBe(200);
    expect(fs.existsSync(path.join(uploadsDir, path.basename(lastUrl))))
      .toBe(false);

    const row = await rowOf(galleryUserId);
    expect(row.vehicle_photos).toBeNull();
    expect(row.vehicle_photo).toBeNull();
    // The raw-row answer is storage-truthful (null); deck-card payloads
    // normalize empties to [] — covered in the nearby suite below.
    expect(res.body.data.vehicle_photos).toBeNull();
    expect(res.body.data.vehicle_photo).toBeNull();
  });
});

describe("GET /api/drivers/nearby carries vehicle_photos", () => {
  const PP_CENTER = { lat: 11.5564, lng: 104.9282 };

  it("includes the array on every deck card — gallery rows AND the "
      + "legacy single-cover fallback", async () => {
    // Fresh gallery content, then make both fixtures pass §8 filters.
    const seeded = await uploadPhotos(authed(request(app).post("/api/drivers/photos")), 3);
    expect(seeded.status).toBe(200);
    uploadedFiles.push(
      ...seeded.body.data.vehicle_photos.map((url) => path.basename(url)),
    );
    await Driver.update(
      { verified: true, online: true, updated_at: new Date() },
      { where: { user_id: { [Op.in]: [galleryUserId, legacyUserId] } } },
    );

    const res = await request(app)
      .get("/api/drivers/nearby")
      .query(PP_CENTER)
      .set("Authorization", `Bearer ${customerToken}`);

    expect(res.status).toBe(200);
    const cards = res.body.data;
    expect(cards.length).toBeGreaterThan(0);
    for (const card of cards) {
      expect(Array.isArray(card.vehicle_photos)).toBe(true);
    }

    const mine = cards.find((c) => c.plate === "PP-5G-0001");
    expect(mine).toBeDefined();
    expect(mine.vehicle_photos).toEqual(seeded.body.data.vehicle_photos);
    expect(mine.vehicle_photo).toBe(mine.vehicle_photos[0]);

    // Pre-column rows fall back to their single cover.
    const legacyCard = cards.find((c) => c.plate === "PP-5G-0002");
    expect(legacyCard).toBeDefined();
    const legacyRow = await rowOf(legacyUserId);
    expect(legacyCard.vehicle_photos).toEqual([legacyRow.vehicle_photo]);

    // Restore canonical flags so sibling suites see the seeded world.
    await Driver.update(
      { verified: false, online: false },
      { where: { user_id: { [Op.in]: [galleryUserId, legacyUserId] } } },
    );
  });
});
