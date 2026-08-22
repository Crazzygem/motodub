import { afterAll, afterEach, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";
import { signToken } from "../src/utils/jwt.js";
import { User, Driver, Ride } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";
import * as rideService from "../src/services/ride.service.js";

// ARCHITECTURE §2 — every transition and invariant lives in RideService.
// Direct service/model calls (no HTTP) keep this suite fast; only the RBAC
// gate "driver cannot create" goes through the app, since that rule lives in
// route middleware, not in the service.
//
// Active-ride states sit on a suite-owned fixture driver, NOT on dara/sophea:
// nearby.test (parallel jest worker) asserts those seeded drivers stay
// deck-visible, and any active ride row excludes them from the deck.

const app = createApp();
const MARKER = "[state-machine-test]";

let srey; // seeded customer — the booking principal
let vithy; // seeded second customer — stranger / fixture holder
let sophea; // seeded driver — wrong-driver accept attempt (never holds rides)
let dara; // seeded driver — wrong-driver decline attempt (never holds rides)
let vuthy; // seeded unverified driver
let admin; // seeded admin — emergency override
let vuthyDriverId;
let fixtureDriver; // suite-owned driver absorbing every active-ride state
let fixtureDriverId;

const originalRatings = {}; // email → users.rating snapshot for restore
let seq = 0;

async function loadUser(email) {
  const user = await User.findOne({ where: { email } });
  expect(user).not.toBeNull();
  return user;
}

function payload(driverRowPk) {
  seq += 1;
  return {
    driverId: driverRowPk,
    pickup: {
      lat: 11.5564,
      lng: 104.9282,
      address: `${MARKER} pickup ${seq}`,
    },
    dropoff: {
      lat: 11.5449,
      lng: 104.8922,
      address: `${MARKER} dropoff ${seq}`,
    },
  };
}

// Fixture escape hatch: the double-accept invariant guards against an illegal
// pre-state (two requested rides on one driver) that create() can never
// produce — so that pre-state must be seeded directly here.
async function seedRequestedRide(customerId, driverUserId, suffix) {
  return Ride.create({
    customer_id: customerId,
    driver_id: driverUserId,
    status: "requested",
    pickup_lat: "11.5564000",
    pickup_lng: "104.9282000",
    pickup_address: `${MARKER} fixture ${suffix}`,
    dropoff_lat: "11.5449000",
    dropoff_lng: "104.8922000",
    dropoff_address: `${MARKER} fixture ${suffix}`,
  });
}

async function wipeMarkerRides() {
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
  });
}

beforeAll(async () => {
  await sequelize.authenticate();
  await wipeMarkerRides(); // idempotent start after a crashed earlier run

  srey = await loadUser("srey@taxi.demo");
  vithy = await loadUser("vithy@taxi.demo");
  sophea = await loadUser("sophea@taxi.demo");
  dara = await loadUser("dara@taxi.demo");
  vuthy = await loadUser("vuthy@taxi.demo");
  admin = await loadUser("admin@taxi.demo");

  const vuthyDriver = await Driver.findOne({ where: { user_id: vuthy.id } });
  vuthyDriverId = vuthyDriver.id;

  const email = `${Date.now()}-state-machine-driver@test.demo`;
  fixtureDriver = await User.create({
    role: "driver",
    name: "Stateful Sam",
    phone: "012346679",
    email,
    password_hash: "not-a-real-login",
  });
  const driverRow = await Driver.create({
    user_id: fixtureDriver.id,
    car_model: "Honda Dream",
    plate: "PP-6V-6666",
    license_no: "KH-DL-6666",
    verified: true,
    online: true,
    price_per_km: "1.00",
    lat: "11.5580000",
    lng: "104.9290000",
    updated_at: new Date(),
  });
  fixtureDriverId = driverRow.id;

  originalRatings[srey.email] = Number(srey.rating);
});

afterEach(async () => {
  // Release srey + the fixture driver immediately between tests.
  await wipeMarkerRides();
});

afterAll(async () => {
  await wipeMarkerRides(); // FK order: rides → drivers → users
  if (fixtureDriver) {
    await Driver.destroy({ where: { user_id: fixtureDriver.id } });
    await fixtureDriver.destroy();
  }
  for (const [email, rating] of Object.entries(originalRatings)) {
    await User.update({ rating }, { where: { email } });
  }
  await sequelize.close();
});

// Full happy prefix: requested → accepted → en_route → in_progress → completed
async function completedRide(customer, driverUser) {
  const ride = await rideService.create(customer.id, payload(fixtureDriverId));
  await rideService.accept(driverUser.id, ride.id);
  await rideService.start(driverUser.id, ride.id);
  await rideService.startRide(driverUser.id, ride.id);
  await rideService.complete(driverUser.id, ride.id);
  return ride.reload();
}

describe("create (Task 3.5 contract preserved)", () => {
  it("creates a requested ride and never touches fare", async () => {
    const body = payload(fixtureDriverId);
    const ride = await rideService.create(srey.id, body);

    expect(ride.status).toBe("requested");
    expect(ride.customer_id).toBe(srey.id);
    expect(ride.driver_id).toBe(fixtureDriver.id);

    // Never-set columns read back NULL from the ROW, not off the fresh
    // instance (ride-create.test convention).
    const row = await Ride.findByPk(ride.id);
    expect(row.fare).toBeNull();
    expect(row.pickup_address).toBe(body.pickup.address);
  });

  it("rejects a second active ride for the same customer (RIDE_BUSY_CUSTOMER)", async () => {
    await rideService.create(srey.id, payload(fixtureDriverId));

    await expect(
      rideService.create(srey.id, payload(fixtureDriverId)),
    ).rejects.toMatchObject({ code: "RIDE_BUSY_CUSTOMER" });
  });

  it("rejects when the target driver already holds an active ride (RIDE_BUSY_DRIVER)", async () => {
    // Fixture customer ≠ booking customer, or the customer invariant fires first.
    await seedRequestedRide(vithy.id, fixtureDriver.id, "busy-driver");

    await expect(
      rideService.create(srey.id, payload(fixtureDriverId)),
    ).rejects.toMatchObject({ code: "RIDE_BUSY_DRIVER" });
  });

  it("rejects booking an unverified driver (DRIVER_NOT_VERIFIED)", async () => {
    await expect(
      rideService.create(srey.id, payload(vuthyDriverId)),
    ).rejects.toMatchObject({ code: "DRIVER_NOT_VERIFIED" });
  });

  it("rejects booking an offline driver (DRIVER_NOT_VERIFIED)", async () => {
    await Driver.update(
      { online: false },
      { where: { user_id: fixtureDriver.id } },
    );
    try {
      await expect(
        rideService.create(srey.id, payload(fixtureDriverId)),
      ).rejects.toMatchObject({ code: "DRIVER_NOT_VERIFIED" });
    } finally {
      await Driver.update(
        { online: true },
        { where: { user_id: fixtureDriver.id } },
      );
    }
  });

  it("rejects an unknown driver with NOT_FOUND", async () => {
    await expect(
      rideService.create(srey.id, payload(999999)),
    ).rejects.toMatchObject({ code: "NOT_FOUND" });
  });

  it("blocks a driver token at the HTTP gate (FORBIDDEN)", async () => {
    const res = await request(app)
      .post("/api/rides")
      .set("Authorization", `Bearer ${signToken({ id: dara.id, role: "driver" })}`)
      .send(payload(fixtureDriverId));

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });
});

describe("accept / decline", () => {
  it("accept transitions requested → accepted", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    const accepted = await rideService.accept(fixtureDriver.id, ride.id);

    expect(accepted.status).toBe("accepted");
  });

  it("decline transitions requested → declined", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    const declined = await rideService.decline(fixtureDriver.id, ride.id);

    expect(declined.status).toBe("declined");
  });

  it("a different driver cannot accept someone else's ride (FORBIDDEN)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    await expect(rideService.accept(sophea.id, ride.id)).rejects.toMatchObject({
      code: "FORBIDDEN",
    });
  });

  it("a different driver cannot decline someone else's ride (FORBIDDEN)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    await expect(rideService.decline(dara.id, ride.id)).rejects.toMatchObject({
      code: "FORBIDDEN",
    });
  });

  it("the customer cannot accept their own ride (FORBIDDEN)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    await expect(rideService.accept(srey.id, ride.id)).rejects.toMatchObject({
      code: "FORBIDDEN",
    });
  });

  it("re-checks driver busyness on accept (double-accept race → RIDE_BUSY_DRIVER)", async () => {
    const first = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, first.id);

    // Illegal pre-state create() prevents: a second requested ride for him.
    const second = await seedRequestedRide(vithy.id, fixtureDriver.id, "race");

    await expect(
      rideService.accept(fixtureDriver.id, second.id),
    ).rejects.toMatchObject({ code: "RIDE_BUSY_DRIVER" });
  });

  it("cannot accept a declined ride (RIDE_INVALID_TRANSITION)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.decline(fixtureDriver.id, ride.id);

    await expect(
      rideService.accept(fixtureDriver.id, ride.id),
    ).rejects.toMatchObject({ code: "RIDE_INVALID_TRANSITION" });
  });
});

describe("start / startRide / complete", () => {
  it("start transitions accepted → en_route", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);

    const enRoute = await rideService.start(fixtureDriver.id, ride.id);

    expect(enRoute.status).toBe("en_route");
  });

  it("startRide transitions en_route → in_progress", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);
    await rideService.start(fixtureDriver.id, ride.id);

    const inProgress = await rideService.startRide(fixtureDriver.id, ride.id);

    expect(inProgress.status).toBe("in_progress");
  });

  it("complete transitions in_progress → completed", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);
    await rideService.start(fixtureDriver.id, ride.id);
    await rideService.startRide(fixtureDriver.id, ride.id);

    const completed = await rideService.complete(fixtureDriver.id, ride.id);

    expect(completed.status).toBe("completed");
  });

  it("cannot complete straight from accepted (RIDE_INVALID_TRANSITION)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);

    await expect(
      rideService.complete(fixtureDriver.id, ride.id),
    ).rejects.toMatchObject({ code: "RIDE_INVALID_TRANSITION" });
  });
});

describe("cancel", () => {
  it("customer cancels from requested", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    const cancelled = await rideService.cancel(srey.id, srey.role, ride.id);

    expect(cancelled.status).toBe("cancelled");
  });

  it("customer cancels from en_route", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);
    await rideService.start(fixtureDriver.id, ride.id);

    const cancelled = await rideService.cancel(srey.id, srey.role, ride.id);

    expect(cancelled.status).toBe("cancelled");
  });

  it("driver cancels from accepted", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);

    const cancelled = await rideService.cancel(
      fixtureDriver.id,
      fixtureDriver.role,
      ride.id,
    );

    expect(cancelled.status).toBe("cancelled");
  });

  it("driver cannot cancel a merely-requested ride (RIDE_INVALID_TRANSITION)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    await expect(
      rideService.cancel(fixtureDriver.id, fixtureDriver.role, ride.id),
    ).rejects.toMatchObject({ code: "RIDE_INVALID_TRANSITION" });
  });

  it("admin emergency-overrides an in_progress ride", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);
    await rideService.start(fixtureDriver.id, ride.id);
    await rideService.startRide(fixtureDriver.id, ride.id);

    const cancelled = await rideService.cancel(admin.id, admin.role, ride.id);

    expect(cancelled.status).toBe("cancelled");
  });

  it("admin cannot cancel a completed ride (RIDE_INVALID_TRANSITION)", async () => {
    const ride = await completedRide(srey, fixtureDriver);

    await expect(
      rideService.cancel(admin.id, admin.role, ride.id),
    ).rejects.toMatchObject({ code: "RIDE_INVALID_TRANSITION" });
  });

  it("a non-participant cannot cancel (FORBIDDEN)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));

    await expect(
      rideService.cancel(vithy.id, vithy.role, ride.id),
    ).rejects.toMatchObject({ code: "FORBIDDEN" });
  });
});

describe("rate", () => {
  // Expected average derives from priors read BEFORE acting, so the assertion
  // checks a genuine recompute without hardcoding seed history.
  async function expectedRatingAfter(targetUserId, receivedColumn, fkColumn, added) {
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

  it("customer rates the driver on a completed ride and the driver's average updates", async () => {
    const ride = await completedRide(srey, fixtureDriver);
    const expected = await expectedRatingAfter(
      fixtureDriver.id,
      "customer_rating",
      "driver_id",
      2,
    );

    const rated = await rideService.rate(srey.id, ride.id, 2);

    expect(rated.customer_rating).toBe(2);
    const driverAfter = await User.findByPk(fixtureDriver.id);
    expect(Number(driverAfter.rating)).toBe(expected);
  });

  it("driver rates the customer on a completed ride and the customer's average updates", async () => {
    const ride = await completedRide(srey, fixtureDriver);
    const expected = await expectedRatingAfter(
      srey.id,
      "driver_rating",
      "customer_id",
      5,
    );

    const rated = await rideService.rate(fixtureDriver.id, ride.id, 5);

    expect(rated.driver_rating).toBe(5);
    const sreyAfter = await User.findByPk(srey.id);
    expect(Number(sreyAfter.rating)).toBe(expected);
  });

  it("rating twice as the same participant fails (RIDE_INVALID_TRANSITION)", async () => {
    const ride = await completedRide(srey, fixtureDriver);
    await rideService.rate(srey.id, ride.id, 4);

    await expect(rideService.rate(srey.id, ride.id, 3)).rejects.toMatchObject({
      code: "RIDE_INVALID_TRANSITION",
    });
  });

  it("rating before completion fails (RIDE_INVALID_TRANSITION)", async () => {
    const ride = await rideService.create(srey.id, payload(fixtureDriverId));
    await rideService.accept(fixtureDriver.id, ride.id);

    await expect(rideService.rate(srey.id, ride.id, 5)).rejects.toMatchObject({
      code: "RIDE_INVALID_TRANSITION",
    });
  });

  it("rejects ratings outside 1–5 or non-integers (VALIDATION_ERROR)", async () => {
    const ride = await completedRide(srey, fixtureDriver);

    for (const bad of [0, 6, 4.5]) {
      await expect(rideService.rate(srey.id, ride.id, bad)).rejects.toMatchObject({
        code: "VALIDATION_ERROR",
      });
    }
  });

  it("a non-participant cannot rate (FORBIDDEN)", async () => {
    const ride = await completedRide(srey, fixtureDriver);

    await expect(rideService.rate(vithy.id, ride.id, 5)).rejects.toMatchObject({
      code: "FORBIDDEN",
    });
  });
});
