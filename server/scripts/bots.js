// Headless demo bot system (Seth-authorized dev/demo tool — not part of
// IMPLEMENTATION.md or the jest suites). Simulated customers + drivers
// speaking the real REST + Socket.IO protocol so the app populates with live
// activity (deck, admin dashboard, history, live map).
//
//   node scripts/bots.js            daemon: drivers drift online, ~1 ride / 90s
//   node scripts/bots.js --burst N  N rides back-to-back, then exit
//   node scripts/bots.js --once     one full ride, then exit
//
// Hygiene: bot accounts only (never touches seeded rows); SIGINT settles or
// cancels every ride it started and flips the bot drivers offline.

const CONFIG = {
  baseUrl: process.env.BOTS_BASE_URL ?? "http://localhost:3000",
  password: "BotDemo@123",
  admin: { email: "admin@taxi.demo", password: "Admin@123" },
  customers: [
    { email: "bot-c1@taxi.demo", name: "Bot Chan", phone: "+855900000101" },
    { email: "bot-c2@taxi.demo", name: "Bot Sopheak", phone: "+855900000102" },
  ],
  drivers: [
    { email: "bot-d1@taxi.demo", name: "Bot Dara", phone: "+855900000201" },
    { email: "bot-d2@taxi.demo", name: "Bot Vireak", phone: "+855900000202" },
  ],
  // Phnom Penh random-walk bounds.
  bounds: { latMin: 11.55, latMax: 11.58, lngMin: 104.9, lngMax: 104.95 },
  heartbeatMs: 8_000, // beats the server's 15s staleness window
  onlineRefreshMs: 60_000,
  rideEveryMs: 90_000,
  declineChance: 0.15,
  daemonStepDelayMs: [2_500, 5_000],
  fastStepDelayMs: [250, 400], // --once / --burst pacing
};

import { io } from "socket.io-client";

const rand = (min, max) => min + Math.random() * (max - min);
const randIn = ([min, max]) => rand(min, max);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (action, detail = "") =>
  console.log(
    `[bot] ${new Date().toISOString().slice(11, 19)} ${action}${detail ? " — " + detail : ""}`,
  );

async function api(method, path, { token, body } = {}) {
  const res = await fetch(CONFIG.baseUrl + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) {
    const err = new Error(json?.error?.message ?? `HTTP ${res.status} ${path}`);
    err.code = json?.error?.code ?? `HTTP_${res.status}`;
    throw err;
  }
  return json.data;
}

function randomPoint() {
  const { latMin, latMax, lngMin, lngMax } = CONFIG.bounds;
  return {
    lat: Number(rand(latMin, latMax).toFixed(6)),
    lng: Number(rand(lngMin, lngMax).toFixed(6)),
  };
}

function walk(pos) {
  const clamp = (v, lo, hi) => Number(Math.min(hi, Math.max(lo, v)).toFixed(6));
  return {
    lat: clamp(pos.lat + rand(-0.0015, 0.0015), CONFIG.bounds.latMin, CONFIG.bounds.latMax),
    lng: clamp(pos.lng + rand(-0.0015, 0.0015), CONFIG.bounds.lngMin, CONFIG.bounds.lngMax),
  };
}

// ---------------------------------------------------------------------------
// Bootstrap — idempotent account/profile/verification setup for bots only.
// ---------------------------------------------------------------------------

async function ensureAccount({ email, name, phone }, role) {
  try {
    const data = await api("POST", "/api/register", {
      body: { name, phone, email, password: CONFIG.password, role },
    });
    log("registered", `${role} ${email}`);
    return data.token;
  } catch {
    const data = await api("POST", "/api/login", {
      body: { email, password: CONFIG.password },
    });
    return data.token;
  }
}

async function bootstrap() {
  const customerTokens = [];
  for (const c of CONFIG.customers) {
    customerTokens.push(await ensureAccount(c, "customer"));
  }

  const driverAccounts = [];
  for (const d of CONFIG.drivers) {
    driverAccounts.push({ ...d, token: await ensureAccount(d, "driver") });
  }

  // Vehicle profile: create-once server-side; "already exists" is success.
  for (const d of driverAccounts) {
    try {
      await api("POST", "/api/drivers", {
        token: d.token,
        body: {
          car_model: pick(["Honda Dream", "Yamaha Sirius", "Honda Wave", "Suzuki Smash"]),
          plate: `PP-${Math.floor(rand(1000, 9999))}`,
          license_no: `L-${Math.floor(rand(10000, 99999))}`,
          price_per_km: Number(rand(1.0, 1.5).toFixed(2)),
        },
      });
      log("profile created", d.email);
    } catch (err) {
      if (err.code !== "VALIDATION_ERROR") throw err;
    }
  }

  // Admin verifies each bot driver (drivers-row PK comes from the admin list,
  // matched by email — bots never appear in seeded data so matching is safe).
  const adminToken = (
    await api("POST", "/api/login", {
      body: { email: CONFIG.admin.email, password: CONFIG.admin.password },
    })
  ).token;

  const rows = await api("GET", "/api/admin/drivers", { token: adminToken });
  for (const d of driverAccounts) {
    const row = rows.find((r) => r.email === d.email);
    if (!row) throw new Error(`no drivers row found for ${d.email}`);
    d.driverId = row.driver_id;
    d.userId = row.user_id;
    if (!row.verified) {
      await api("POST", `/api/admin/drivers/${row.driver_id}/verify`, { token: adminToken });
      log("verified by admin", d.email);
    }
    d.pos = randomPoint();
    await api("PATCH", "/api/drivers/online", {
      token: d.token,
      body: { online: true, ...d.pos },
    });
  }

  return { customerTokens, driverAccounts };
}

// ---------------------------------------------------------------------------
// Registry — tracks every ride the bots started so shutdown leaves nothing
// active behind.
// ---------------------------------------------------------------------------

const registry = {
  rides: new Map(), // rideId -> {customerToken, driverToken, label}
  stopping: false,
  add(id, info) {
    this.rides.set(id, { ...(this.rides.get(id) ?? {}), ...info });
  },
};

async function settleRide(rideId, { customerToken, driverToken } = {}) {
  let status = null;
  try {
    // Either participant may read the ride — socket-triggered entries (rides
    // booked by an external customer onto a bot driver) carry no customerToken.
    status = (await api("GET", `/api/rides/${rideId}`, { token: customerToken ?? driverToken })).status;
  } catch {
    return;
  }
  try {
    if (status === "requested") {
      if (!customerToken) {
        // §2: drivers cannot cancel from requested — not our ride, leave it.
        log("cleanup skipped", `#${rideId} requested by an external customer — left untouched`);
        registry.rides.delete(rideId);
        return;
      }
      await api("POST", `/api/rides/${rideId}/cancel`, { token: customerToken });
      log("cleanup cancelled", `#${rideId}`);
    } else if (status === "accepted" && driverToken) {
      await api("POST", `/api/rides/${rideId}/start`, { token: driverToken });
      await api("POST", `/api/rides/${rideId}/start-ride`, { token: driverToken });
      await api("POST", `/api/rides/${rideId}/complete`, { token: driverToken });
      log("cleanup completed", `#${rideId}`);
    } else if (status === "en_route" && driverToken) {
      await api("POST", `/api/rides/${rideId}/start-ride`, { token: driverToken });
      await api("POST", `/api/rides/${rideId}/complete`, { token: driverToken });
      log("cleanup completed", `#${rideId}`);
    } else if (status === "in_progress" && driverToken) {
      await api("POST", `/api/rides/${rideId}/complete`, { token: driverToken });
      log("cleanup completed", `#${rideId}`);
    }
  } catch (err) {
    log("cleanup error", `#${rideId} ${err.code}: ${err.message}`);
  }
  registry.rides.delete(rideId);
}

async function cleanup(drivers) {
  registry.stopping = true;
  for (const [id, info] of registry.rides) await settleRide(id, info);
  for (const d of drivers) {
    for (const t of d.timers ?? []) clearInterval(t);
    d.socket?.disconnect();
    try {
      await api("PATCH", "/api/drivers/online", { token: d.token, body: { online: false } });
      log("driver offline", d.email);
    } catch (err) {
      log("offline failed", `${d.email}: ${err.message}`);
    }
  }
}

// ---------------------------------------------------------------------------
// Driver runtime — WS heartbeat + accept/(decline)/drive/rate state machine.
// ---------------------------------------------------------------------------

/** Exactly-once gate: whichever trigger wins (socket event or customer call). */
function claimDrive(account, rideId, stepDelay) {
  if (account.busy || account.handled.has(rideId)) return false;
  account.handled.add(rideId);
  account.busy = true;
  registry.add(rideId, { driverToken: account.token });
  void driveRide(account, rideId, stepDelay);
  return true;
}

async function driveRide(account, rideId, stepDelay) {
  // Once stopping, cleanup owns the ride — bail instead of racing it.
  const guard = () => !registry.stopping;
  try {
    if (guard() && Math.random() < CONFIG.declineChance) {
      await api("POST", `/api/rides/${rideId}/decline`, { token: account.token });
      log("ride declined", `#${rideId} (variety path)`);
    } else {
      if (!guard()) return;
      await api("POST", `/api/rides/${rideId}/accept`, { token: account.token });
      log("ride accepted", `#${rideId}`);
      await sleep(randIn(stepDelay));
      if (!guard()) return;
      await api("POST", `/api/rides/${rideId}/start`, { token: account.token });
      log("driver en route", `#${rideId}`);
      await sleep(randIn(stepDelay));
      if (!guard()) return;
      await api("POST", `/api/rides/${rideId}/start-ride`, { token: account.token });
      log("ride started", `#${rideId}`);
      await sleep(randIn(stepDelay));
      if (!guard()) return;
      await api("POST", `/api/rides/${rideId}/complete`, { token: account.token });
      log("ride completed", `#${rideId}`);
      const stars = pick([4, 5]);
      await api("POST", `/api/rides/${rideId}/rate`, { token: account.token, body: { stars } });
      log(`driver rated ${stars}*`, `#${rideId}`);
    }
  } catch (err) {
    log("driver error", `#${rideId} ${err.code}: ${err.message}`);
  } finally {
    account.busy = false;
  }
}

function startDriver(account, stepDelay) {
  account.busy = false;
  account.handled = new Set(); // ride ids already claimed by either trigger
  const socket = io(CONFIG.baseUrl, {
    transports: ["websocket"],
    auth: { token: account.token },
  });
  account.socket = socket;

  socket.on("connect", () => log("driver online", account.email));
  socket.on("connect_error", (err) => log("driver socket error", `${account.email}: ${err.message}`));

  // The server announces ride:requested as soon as the row commits — possibly
  // before the customer's POST response arrives. Both triggers funnel into
  // claimDrive, which is exactly-once per ride id.
  socket.on("ride:requested", (evt) => claimDrive(account, evt.rideId, stepDelay));

  // Heartbeat: WS location:update stamps updated_at; periodic REST online
  // refresh is belt-and-braces freshness if the socket ever drops.
  account.timers = [
    setInterval(() => {
      account.pos = walk(account.pos);
      socket.emit("location:update", account.pos);
      log("heartbeat", `${account.email} @ ${account.pos.lat},${account.pos.lng}`);
    }, CONFIG.heartbeatMs),
    setInterval(() => {
      api("PATCH", "/api/drivers/online", {
        token: account.token,
        body: { online: true, ...account.pos },
      }).catch((err) => log("online refresh failed", err.message));
    }, CONFIG.onlineRefreshMs),
  ];
}

// ---------------------------------------------------------------------------
// Customer side — book nearest free BOT driver, wait for terminal status,
// rate if completed. Resolves with the ride id (or null if nothing booked).
// ---------------------------------------------------------------------------

async function runRide(label, customerToken, drivers, stepDelay) {
  const c = randomPoint();
  const nearby = await api("GET", `/api/drivers/nearby?lat=${c.lat}&lng=${c.lng}`, {
    token: customerToken,
  });
  // Bots book bot drivers only (hygiene rule).
  const target = nearby.find((card) => drivers.some((d) => d.driverId === card.id && !d.busy));
  if (!target) {
    log("no bookable bot driver", `${nearby.length} nearby card(s), ${drivers.filter((d) => !d.busy).length} bot(s) free`);
    return null;
  }

  const dropoff = randomPoint();
  const ride = await api("POST", "/api/rides", {
    token: customerToken,
    body: {
      driverId: target.id,
      pickup: { ...c, address: "Bot pickup, Phnom Penh" },
      dropoff: { ...dropoff, address: "Bot dropoff, Phnom Penh" },
    },
  });
  const driver = drivers.find((d) => d.driverId === target.id);
  registry.add(ride.id, { customerToken, driverToken: driver?.token, label });
  log("ride booked", `#${ride.id} by ${label} → ${target.name} (${target.car_model})`);

  // Trigger the booked driver directly — the socket announcement may land
  // before this POST response does; claimDrive makes both exactly-once.
  claimDrive(driver, ride.id, stepDelay);

  // Sockets announce; REST is the source of truth — poll to terminal state.
  const terminal = ["completed", "cancelled", "declined"];
  let status = "requested";
  const deadline = Date.now() + 45_000;
  while (!terminal.includes(status) && Date.now() < deadline) {
    await sleep(400);
    try {
      status = (await api("GET", `/api/rides/${ride.id}`, { token: customerToken })).status;
    } catch {
      break;
    }
  }

  if (status === "completed") {
    const stars = pick([4, 5]);
    await api("POST", `/api/rides/${ride.id}/rate`, { token: customerToken, body: { stars } });
    log(`customer rated ${stars}*`, `#${ride.id}`);
  }
  registry.rides.delete(ride.id);
  log("ride settled", `#${ride.id} final=${status}`);
  return { id: ride.id, status };
}

// ---------------------------------------------------------------------------
// Modes + orchestration.
// ---------------------------------------------------------------------------

async function main() {
  const arg = process.argv[2];
  const burstN = arg === "--burst" ? Math.max(0, Number(process.argv[3] ?? 0)) : null;
  const once = arg === "--once";
  if (arg && arg !== "--burst" && !once) {
    console.log("usage: node scripts/bots.js [--burst N | --once]");
    process.exit(1);
  }

  log("bootstrapping", CONFIG.baseUrl);
  // Fast modes exist for deterministic screenshots/verification ("--burst N
  // → N completed"), so the daemon-only 15% decline variety is off there.
  if (once || burstN !== null) CONFIG.declineChance = 0;
  const { customerTokens, driverAccounts } = await bootstrap();
  log(
    "bootstrap done",
    `${customerTokens.length} customers · ${driverAccounts.length} drivers verified+online`,
  );

  let completed = 0;
  const stepDelay = once || burstN !== null ? CONFIG.fastStepDelayMs : CONFIG.daemonStepDelayMs;
  for (const d of driverAccounts) startDriver(d, stepDelay);
  await sleep(500); // let sockets connect before the first booking

  let riderIdx = 0;
  async function launchRide() {
    const idx = riderIdx % customerTokens.length;
    riderIdx++;
    try {
      const result = await runRide(`c${idx + 1}`, customerTokens[idx], driverAccounts, stepDelay);
      if (result && result.status === "completed") completed++;
      return true;
    } catch (err) {
      log("ride error", `c${idx + 1}: ${err.code}: ${err.message}`);
      return false;
    }
  }

  let shuttingDown = false;
  async function shutdown(exitCode = 0) {
    if (shuttingDown) return;
    shuttingDown = true;
    registry.stopping = true;
    log("shutting down", `${completed} completed ride(s) this session`);
    await cleanup(driverAccounts);
    process.exit(exitCode);
  }
  process.on("SIGINT", () => void shutdown());
  process.on("SIGTERM", () => void shutdown());

  if (once || burstN !== null) {
    const total = burstN ?? 1;
    for (let i = 0; i < total; i++) {
      const ok = await launchRide(); // sequential = back-to-back, race-free
      if (!ok) await shutdown(1);
    }
    log("target reached", `${completed}/${total} completed`);
    await shutdown(completed === total ? 0 : 1);
  } else {
    log("daemon started", `rides every ~${CONFIG.rideEveryMs / 1000}s (Ctrl+C to stop)`);
    while (!shuttingDown) {
      await sleep(CONFIG.rideEveryMs * rand(0.85, 1.15));
      if (!shuttingDown) {
        await launchRide();
        log("daemon idle", `${completed} completed so far`);
      }
    }
  }
}

main().catch((err) => {
  console.error(`[bot] fatal: ${err.message}`);
  process.exit(1);
});
