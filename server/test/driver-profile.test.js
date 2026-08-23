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

function getMe(token) {
  return request(app)
    .get("/api/drivers/me")
    .set("Authorization", `Bearer ${token}`);
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
    await Driver.create({
      user_id: onlineDriver.id,
      car_model: "Honda Dream",
      plate: "PP-2B-2222",
      license_no: "KH-DL-2222",
      price_per_km: "1.00",
    });

    // Backdate so the bump below is unambiguous. Staleness math happens in
    // SQL against the DB's own clock — client-side Date values are silently
    // dropped here (timestamp-only Model.update values are discarded by
    // Sequelize's auto-stamping), which made this suite's old backdate a
    // no-op and its bump assertion vacuous.
    const row = await Driver.findOne({ where: { user_id: onlineDriver.id } });
    await sequelize.query(
      "UPDATE drivers SET updated_at = NOW() - INTERVAL 60 SECOND WHERE id = :id",
      { replacements: { id: row.id } },
    );
    // Second-precision DATETIME: compare against the backdated value so the
    // bump cannot land "in the same second" as the reference.
    const before = new Date(
      (await Driver.findOne({ where: { user_id: onlineDriver.id } }))
        .updated_at,
    ).getTime();

    const res = await patchOnline(
      { online: true, lat: 11.5564, lng: 104.9282 },
      signToken({ id: onlineDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.online).toBe(true);

    const bumped = await Driver.findOne({
      where: { user_id: onlineDriver.id },
    });
    expect(Number(bumped.lat)).toBeCloseTo(11.5564, 5);
    expect(Number(bumped.lng)).toBeCloseTo(104.9282, 5);
    expect(new Date(bumped.updated_at).getTime()).toBeGreaterThan(before);
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

  it("drops a verified driver from the nearby deck once the heartbeat goes stale, and restores them on refresh", async () => {
    // Make him deck-eligible. Position FIRST (while still unverified and
    // therefore invisible): nearby.test.js runs in a parallel jest worker
    // against this same database and asserts every returned card has a
    // distance > 0, so a verified driver must never sit on the query center.
    const reposition = await patchOnline(
      { online: true, lat: 11.558, lng: 104.929 },
      signToken({ id: onlineDriver.id, role: "driver" }),
    );
    expect(reposition.status).toBe(200);
    await Driver.update(
      { verified: true },
      { where: { user_id: onlineDriver.id } },
    );

    async function nearbyNames() {
      const res = await request(app)
        .get("/api/drivers/nearby")
        .query({ lat: 11.5564, lng: 104.9282 })
        .set("Authorization", `Bearer ${customerToken}`);
      expect(res.status).toBe(200);
      return res.body.data.map((c) => c.name);
    }

    // Fresh heartbeat → visible.
    expect(await nearbyNames()).toContain("Heartbeat Heng");

    // Backdate past §8's 15s freshness window with SQL-side clock math —
    // client-side timestamp writes are silently dropped by Sequelize (see
    // the heartbeat test above).
    const row = await Driver.findOne({ where: { user_id: onlineDriver.id } });
    await sequelize.query(
      "UPDATE drivers SET updated_at = NOW() - INTERVAL 60 SECOND WHERE id = :id",
      { replacements: { id: row.id } },
    );

    // Stale heartbeat → treated as offline, excluded from the deck.
    expect(await nearbyNames()).not.toContain("Heartbeat Heng");

    // A fresh bump puts him straight back in — proving the exclusion was
    // the staleness filter, not the verification flip.
    const refresh = await patchOnline(
      { online: true, lat: 11.558, lng: 104.929 },
      signToken({ id: onlineDriver.id, role: "driver" }),
    );
    expect(refresh.status).toBe(200);
    expect(await nearbyNames()).toContain("Heartbeat Heng");
  });
});

describe("GET /api/drivers/me", () => {
  it("rejects a customer with FORBIDDEN", async () => {
    const res = await getMe(customerToken);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("returns NOT_FOUND for a driver without a profile yet (first-time setup)", async () => {
    const res = await getMe(signToken({ id: 987654, role: "driver" }));

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });

  it("returns the signed-in driver's own vehicle profile", async () => {
    const res = await getMe(
      signToken({ id: profileDriver.id, role: "driver" }),
    );

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    // PATCH /api/drivers above set these — the read must reflect them.
    expect(res.body.data).toMatchObject({
      user_id: profileDriver.id,
      car_model: "Yamaha FX",
      plate: "PP-1A-1111",
      license_no: "KH-DL-1111",
      verified: false,
      online: false,
    });
  });
});
