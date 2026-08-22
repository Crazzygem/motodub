import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import { Op } from "sequelize";
import { signToken } from "../src/utils/jwt.js";
import { User, Driver, Ride } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

const app = createApp();
const MARKER = "[ride-create-test]"; // identifies fixture rides for cleanup

let customerToken;
let customer;
let bookableDriver; // dedicated verified driver — never the seeded ones, so
// this suite's ACTIVE rides can't shadow dara in the parallel nearby suite
let vuthyDriverId;
let busyDriverUser;
let busyDriverRow;
const fixtureEmails = [];

async function cleanupFixtures() {
  // FK order: rides → drivers → users. LIKE match: addresses carry MARKER
  // plus a venue suffix.
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
  });
  if (busyDriverRow) await busyDriverRow.destroy();
  if (bookableDriver) await bookableDriver.destroy();
  await User.destroy({ where: { email: { [Op.in]: fixtureEmails } } });
}

beforeAll(async () => {
  await sequelize.authenticate();

  // Idempotent start: a crashed earlier run may have left MARKER rides that
  // would make this customer look already-booked.
  await Ride.destroy({
    where: { pickup_address: { [Op.like]: `%${MARKER}%` } },
  });

  // Unique per-run customer (nearby.test convention) so RIDE_BUSY_CUSTOMER is
  // deterministic regardless of what earlier suites left in the table.
  const custEmail = `${Date.now()}-ride-cust@test.demo`;
  fixtureEmails.push(custEmail);
  const reg = await request(app).post("/api/register").send({
    name: "Ride Customer",
    phone: "012345671",
    email: custEmail,
    password: "Password1",
  });
  expect(reg.status).toBe(201);
  customerToken = reg.body.data.token;
  customer = await User.findOne({ where: { email: custEmail } });

  // Verified + online target driver. The wire contract carries drivers.id —
  // the deck card id — as driverId.
  const bookableEmail = `${Date.now()}-ride-driver@test.demo`;
  fixtureEmails.push(bookableEmail);
  const bookableUser = await User.create({
    role: "driver",
    name: "Bookable Nary",
    phone: "012555574",
    email: bookableEmail,
    password_hash: "not-a-real-login",
  });
  bookableDriver = await Driver.create({
    user_id: bookableUser.id,
    car_model: "Honda Dream",
    plate: "PP-7X-7777",
    license_no: "KH-DL-7777",
    verified: true,
    online: true,
    price_per_km: "1.00",
    lat: "11.5580000",
    lng: "104.9290000",
    updated_at: new Date(),
  });

  // Vuthy is the seeded unverified driver (read-only use below).
  const vuthy = await User.findOne({ where: { email: "vuthy@taxi.demo" } });
  const vuthyDriver = await Driver.findOne({ where: { user_id: vuthy.id } });
  vuthyDriverId = vuthyDriver.id;

  // Extra verified driver holding an ACTIVE ride → target of the
  // RIDE_BUSY_DRIVER check even though they pass every deck filter.
  const busyEmail = `${Date.now()}-ride-busy@test.demo`;
  fixtureEmails.push(busyEmail);
  busyDriverUser = await User.create({
    role: "driver",
    name: "Busy Bona",
    phone: "012888887",
    email: busyEmail,
    password_hash: "not-a-real-login",
  });

  const otherCustEmail = `${Date.now()}-ride-other@test.demo`;
  fixtureEmails.push(otherCustEmail);
  const otherCustomer = await User.create({
    role: "customer",
    name: "Other Customer",
    phone: "012777776",
    email: otherCustEmail,
    password_hash: "not-a-real-login",
  });

  busyDriverRow = await Driver.create({
    user_id: busyDriverUser.id,
    car_model: "Honda Dream",
    plate: "PP-8Y-8888",
    license_no: "KH-DL-8888",
    verified: true,
    online: true,
    price_per_km: "1.00",
    lat: "11.5580000",
    lng: "104.9290000",
    updated_at: new Date(),
  });
  await Ride.create({
    customer_id: otherCustomer.id,
    driver_id: busyDriverUser.id,
    status: "requested",
    pickup_lat: "11.5564000",
    pickup_lng: "104.9282000",
    pickup_address: `${MARKER} Central Market`,
    dropoff_lat: "11.5484000",
    dropoff_lng: "104.8928000",
    dropoff_address: `${MARKER} Airport`,
  });
});

afterAll(async () => {
  await cleanupFixtures();
  await sequelize.close();
});

function book(body, token = customerToken) {
  return request(app)
    .post("/api/rides")
    .set("Authorization", `Bearer ${token}`)
    .send(body);
}

const validBody = (driverId) => ({
  driverId,
  pickup: { lat: 11.5564, lng: 104.9282, address: `${MARKER} Central Market` },
  dropoff: { lat: 11.5449, lng: 104.8922, address: `${MARKER} Airport` },
});

describe("POST /api/rides", () => {
  it("creates a requested ride for a customer and returns it", async () => {
    const res = await book(validBody(bookableDriver.id));

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toMatchObject({
      customer_id: customer.id,
      driver_id: bookableDriver.user_id,
      status: "requested",
      pickup_address: `${MARKER} Central Market`,
      dropoff_address: `${MARKER} Airport`,
    });
    expect(Number(res.body.data.pickup_lat)).toBeCloseTo(11.5564, 5);

    // The wire payload may omit never-set columns; the ROW must have them
    // NULL — fare is reserved and never stored (§9).
    const row = await Ride.findByPk(res.body.data.id);
    expect(row).not.toBeNull();
    expect(row.fare).toBeNull();
    expect(row.customer_rating).toBeNull();
    expect(row.driver_rating).toBeNull();
  });

  it("rejects a driver token with FORBIDDEN", async () => {
    const res = await book(
      validBody(bookableDriver.id),
      signToken({ id: bookableDriver.user_id, role: "driver" }),
    );

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe("FORBIDDEN");
  });

  it("rejects a malformed payload with VALIDATION_ERROR", async () => {
    const res = await book({
      driverId: bookableDriver.id,
      pickup: { lat: 11.5564, lng: 104.9282 }, // address missing
      dropoff: validBody(bookableDriver.id).dropoff,
    });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("returns NOT_FOUND for an unknown driver", async () => {
    const res = await book(validBody(999999));

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });

  it("returns DRIVER_NOT_VERIFIED for an unverified driver", async () => {
    const res = await book(validBody(vuthyDriverId));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("DRIVER_NOT_VERIFIED");
  });

  it("returns RIDE_BUSY_CUSTOMER when the customer already has an active ride", async () => {
    // The happy-path ride above is still active for this fresh customer.
    const res = await book(validBody(busyDriverRow.id));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("RIDE_BUSY_CUSTOMER");
  });

  it("returns RIDE_BUSY_DRIVER when the targeted driver has an active ride", async () => {
    // Fresh customer, but Busy Bona already holds a requested ride.
    const email = `${Date.now()}-ride-fresh@test.demo`;
    fixtureEmails.push(email);
    const reg = await request(app).post("/api/register").send({
      name: "Fresh Customer",
      phone: "012666675",
      email,
      password: "Password1",
    });
    expect(reg.status).toBe(201);

    const res = await book(validBody(busyDriverRow.id), reg.body.data.token);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("RIDE_BUSY_DRIVER");
  });
});
