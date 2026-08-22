import "dotenv/config";
import bcrypt from "bcryptjs";
import { sequelize } from "../config/db.js";
import { User, Driver, Ride } from "../models/index.js";

// Demo accounts (PROJECT.md §5). Idempotent: find by email → update or create.
const USERS = [
  {
    role: "admin",
    name: "Admin",
    phone: "+855 100 000",
    email: "admin@taxi.demo",
    password: "Admin@123",
  },
  {
    role: "customer",
    name: "Srey",
    phone: "+855 111 111",
    email: "srey@taxi.demo",
    password: "Demo@123",
  },
  {
    role: "customer",
    name: "Vithy",
    phone: "+855 222 222",
    email: "vithy@taxi.demo",
    password: "Demo@123",
  },
  {
    role: "driver",
    name: "Dara",
    phone: "+855 333 333",
    email: "dara@taxi.demo",
    password: "Demo@123",
  },
  {
    role: "driver",
    name: "Sophea",
    phone: "+855 444 444",
    email: "sophea@taxi.demo",
    password: "Demo@123",
  },
  {
    role: "driver",
    name: "Vuthy",
    phone: "+855 555 555",
    email: "vuthy@taxi.demo",
    password: "Demo@123",
  },
];

// All within ~2 km of Phnom Penh center (11.5564, 104.9282).
const DRIVERS = [
  {
    email: "dara@taxi.demo",
    car_model: "Toyota Highlander SUV",
    plate: "PP-1A-2345",
    license_no: "KH-DL-0001",
    verified: true,
    online: true,
    price_per_km: "1.20",
    lat: "11.5620000",
    lng: "104.9180000",
  },
  {
    email: "sophea@taxi.demo",
    car_model: "Toyota Corolla sedan",
    plate: "PP-2B-3456",
    license_no: "KH-DL-0002",
    verified: true,
    online: true,
    price_per_km: "0.90",
    lat: "11.5505000",
    lng: "104.9350000",
  },
  {
    email: "vuthy@taxi.demo",
    car_model: "Hyundai Accent sedan",
    plate: "PP-3C-4567",
    license_no: "KH-DL-0003",
    verified: false,
    online: false,
    price_per_km: "1.50",
    lat: "11.5470000",
    lng: "104.9210000",
  },
];

// fare stays NULL — reserved column, never set (ARCHITECTURE §9).
const RIDES = [
  {
    customer_email: "srey@taxi.demo",
    driver_email: "dara@taxi.demo",
    status: "completed",
    pickup_lat: "11.5566000",
    pickup_lng: "104.9237000",
    pickup_address: "Central Market, Phnom Penh",
    dropoff_lat: "11.5484000",
    dropoff_lng: "104.8928000",
    dropoff_address: "Aeon Mall 1, Phnom Penh",
    customer_rating: 5,
    driver_rating: 5,
  },
  {
    customer_email: "srey@taxi.demo",
    driver_email: "sophea@taxi.demo",
    status: "completed",
    pickup_lat: "11.5573000",
    pickup_lng: "104.9319000",
    pickup_address: "Sisowath Quay (Riverside), Phnom Penh",
    dropoff_lat: "11.5480000",
    dropoff_lng: "104.9166000",
    dropoff_address: "Russian Market, Phnom Penh",
    customer_rating: 4,
    driver_rating: 5,
  },
];

// Upsert-style: find by key, update with seed values or create.
async function upsert(model, where, values) {
  const row = await model.findOne({ where });
  if (row) return row.update(values);
  return model.create({ ...where, ...values });
}

async function seed() {
  const usersByEmail = {};
  for (const u of USERS) {
    const { password, ...fields } = u;
    usersByEmail[u.email] = await upsert(User, { email: u.email }, {
      ...fields,
      password_hash: await bcrypt.hash(password, 10),
    });
  }

  for (const d of DRIVERS) {
    const user = usersByEmail[d.email];
    // updated_at is the location heartbeat — keep it fresh on every run.
    await upsert(Driver, { user_id: user.id }, { ...d, updated_at: new Date() });
  }

  for (const r of RIDES) {
    const customer = usersByEmail[r.customer_email];
    const driver = usersByEmail[r.driver_email];
    const { customer_email, driver_email, ...fields } = r;
    await upsert(
      Ride,
      { customer_id: customer.id, driver_id: driver.id },
      fields,
    );
  }

  console.log(`seeded: ${USERS.length} users, ${DRIVERS.length} drivers, ${RIDES.length} rides`);
}

if (process.argv.includes("--reset")) {
  console.log("seed:reset — dropping and recreating all tables (dev only)");
  await sequelize.sync({ force: true });
}

await sequelize.authenticate();
await seed();
await sequelize.close();
