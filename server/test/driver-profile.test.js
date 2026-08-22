import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";
import { signToken } from "../src/utils/jwt.js";
import { User, Driver } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

const app = createApp();

let customerToken;
let profileDriver; // exercises POST /api/drivers create-once + PATCH /api/drivers
let onlineDriver; // exercises PATCH /api/drivers/online heartbeat semantics
let deckDriver; // unverified driver proving online-but-invisible in the deck
const fixtureEmails = [];
const createdDriverUserIds = [];

async function cleanupFixtures() {
  // FK order: drivers → users
  await Driver.destroy({ where: { user_id: { [Op.in]: createdDriverUserIds } } });
  await User.destroy({ where: { email: { [Op.in]: fixtureEmails } } });
}

beforeAll(async () => {
  await sequelize.authenticate();

  const custEmail = `${Date.now()}-driver-prof-cust@test.demo`;
  fixtureEmails.push(custEmail);
  const reg = await request(app).post("/api/register").send({
    name: "Profile Customer",
    phone: "012346678",
    email: custEmail,
    password: "Password1",
  });
  expect(reg.status).toBe(201);
  customerToken = reg.body.data.token;

  for (const [name, phone, suffix] of [
    ["Profiling Piseth", "012444441", "profile"],
    ["Heartbeat Heng", "012444442", "online"],
    ["Deck Dara Jr", "012444443", "deck"],
  ]) {
    const email = `${Date.now()}-driver-${suffix}@test.demo`;
    fixtureEmails.push(email);
    const user = await User.create({
      role: "driver",
      name,
      phone,
      email,
      password_hash: "not-a-real-login",
    });
    createdDriverUserIds.push(user.id);
    if (suffix === "profile") profileDriver = user;
    if (suffix === "online") onlineDriver = user;
    if (suffix === "deck") {
      deckDriver = user;
      // Unverified profile that already exists — the subject of the
      // online-but-invisible deck assertion below.
      await Driver.create({
        user_id: user.id,
        car_model: "Honda Dream",
        plate: "PP-3C-3333",
        license_no: "KH-DL-3333",
        price_per_km: "1.00",
        updated_at: new Date(),
      });
    }
  }
});

afterAll(async () => {
  await cleanupFixtures();
  await sequelize.close();
});

function postProfile(body, token) {
  return request(app)
    .post("/api/drivers")
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

function patchDrivers(body, token) {
  return request(app)
    .patch("/api/drivers")
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

function patchOnline(body, token) {
  return request(app)
    .patch("/api/drivers/online")
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

const vehicleBody = {
  car_model: "Honda Dream",
  plate: "PP-1A-1111",
  license_no: "KH-DL-1111",
  price_per_km: 1.5,
};

describe("POST /api/drivers", () => {
  it("rejects a customer with FORBIDDEN", async () => {
    const res = await postProfile(vehicleBody, customerToken);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("rejects an admin with FORBIDDEN", async () => {
    const token = signToken({ id: 999999, role: "admin" });
    const res = await postProfile(vehicleBody, token);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("creates an unverified profile linked to the current driver", async () => {
    const res = await postProfile(
      vehicleBody,
      signToken({ id: profileDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toMatchObject({
      user_id: profileDriver.id,
      car_model: "Honda Dream",
      plate: "PP-1A-1111",
      license_no: "KH-DL-1111",
      verified: false,
      online: false,
    });
    expect(Number(res.body.data.price_per_km)).toBeCloseTo(1.5, 2);

    const row = await Driver.findOne({ where: { user_id: profileDriver.id } });
    expect(row).not.toBeNull();
    expect(row.verified).toBe(false); // admin verification is a later task
  });

  it("returns VALIDATION_ERROR when a profile already exists (create-once)", async () => {
    const res = await postProfile(
      vehicleBody,
      signToken({ id: profileDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects a malformed payload with VALIDATION_ERROR", async () => {
    const res = await postProfile(
      { car_model: "Honda Dream" }, // plate/license_no/price_per_km missing
      signToken({ id: onlineDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});

describe("PATCH /api/drivers", () => {
  it("updates own vehicle fields and persists them", async () => {
    const res = await patchDrivers(
      {
        car_model: "Yamaha FX",
        price_per_km: 2.0,
      },
      signToken({ id: profileDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const row = await Driver.findOne({ where: { user_id: profileDriver.id } });
    expect(row.car_model).toBe("Yamaha FX");
    expect(Number(row.price_per_km)).toBeCloseTo(2.0, 2);
    expect(row.plate).toBe("PP-1A-1111"); // untouched field survives
  });

  it("rejects an empty update with VALIDATION_ERROR", async () => {
    const res = await patchDrivers(
      {},
      signToken({ id: profileDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects a driver without a profile with NOT_FOUND", async () => {
    const res = await patchDrivers(
      { car_model: "Ghost Bike" },
      signToken({ id: onlineDriver.id, role: "driver" }), // no profile yet
    );

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });
});

describe("PATCH /api/drivers/online", () => {
  it("goes online, persists lat/lng and bumps the updated_at heartbeat", async () => {
    // Backdate the heartbeat so the bump below is unambiguous (DATE is
    // second-precision, hence the hour).
    const stale = new Date(Date.now() - 60 * 60 * 1000);
    await Driver.update(
      { updated_at: stale },
      { where: { user_id: onlineDriver.id } },
    );
    await Driver.create({
      user_id: onlineDriver.id,
      car_model: "Honda Dream",
      plate: "PP-2B-2222",
      license_no: "KH-DL-2222",
      price_per_km: "1.00",
      updated_at: stale,
    });

    const res = await patchOnline(
      { online: true, lat: 11.5564, lng: 104.9282 },
      signToken({ id: onlineDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.online).toBe(true);

    const row = await Driver.findOne({ where: { user_id: onlineDriver.id } });
    expect(Number(row.lat)).toBeCloseTo(11.5564, 5);
    expect(Number(row.lng)).toBeCloseTo(104.9282, 5);
    expect(new Date(row.updated_at).getTime()).toBeGreaterThan(
      stale.getTime(),
    );
  });

  it("rejects a toggle without a boolean with VALIDATION_ERROR", async () => {
    const res = await patchOnline(
      { lat: 11.5564 }, // online missing
      signToken({ id: onlineDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("lets an UNVERIFIED driver go online but keeps them out of the nearby deck", async () => {
    const res = await patchOnline(
      { online: true, lat: 11.5564, lng: 104.9282 },
      signToken({ id: deckDriver.id, role: "driver" }),
    );

    // The toggle itself succeeds — verification is not its business.
    expect(res.status).toBe(200);
    expect(res.body.data.online).toBe(true);

    // §8 nearby filters on verified=1, so the fresh heartbeat must NOT
    // surface this unverified driver.
    const deck = await request(app)
      .get("/api/drivers/nearby")
      .query({ lat: 11.5564, lng: 104.9282 })
      .set("Authorization", `Bearer ${customerToken}`);

    expect(deck.status).toBe(200);
    expect(deck.body.data.map((c) => c.name)).not.toContain("Deck Dara Jr");
  });
});
