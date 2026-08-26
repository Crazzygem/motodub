// MotoDub demo bots — ONE implementation, two hosts.
//
// The BotManager class is the whole bot system extracted from scripts/bots.js:
// idempotent bootstrap of bot-* accounts (register/login → vehicle profile →
// admin verification → optional Openverse vehicle photos), per-driver WS
// heartbeat + ride state machine, and a customer-side booking loop speaking
// the real REST + Socket.IO protocol.
//
//   CLI host      scripts/bots.js (--once/--burst/--daemon) — dev/demo tool.
//   Embedded host src/controllers/admin.controller.js — Seth directive: the
//                 admin app can DEPLOY driver bots on demand (default OFF,
//                 never started at boot) via POST/DELETE /api/admin/bots.
//
// Hygiene unchanged: bot accounts only (never seeded rows); stop() settles or
// cancels every ride the session started and flips the bot drivers offline.

const CONFIG = {
  password: "BotDemo@123",
  admin: { email: "admin@taxi.demo", password: "Admin@123" },
  // Three customer/driver pairs; a manager runs the first `count` of each.
  customers: [
    { email: "bot-c1@taxi.demo", name: "Bot Chan", phone: "+855900000101" },
    { email: "bot-c2@taxi.demo", name: "Bot Sopheak", phone: "+855900000102" },
    { email: "bot-c3@taxi.demo", name: "Bot Dalia", phone: "+855900000103" },
  ],
  drivers: [
    { email: "bot-d1@taxi.demo", name: "Bot Dara", phone: "+855900000201" },
    { email: "bot-d2@taxi.demo", name: "Bot Vireak", phone: "+855900000202" },
    { email: "bot-d3@taxi.demo", name: "Bot Ravy", phone: "+855900000203" },
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
const defaultLog = (action, detail = "") =>
  console.log(
    `[bot] ${new Date().toISOString().slice(11, 19)} ${action}${detail ? " — " + detail : ""}`,
  );

function defaultBaseUrl() {
  return process.env.BOTS_BASE_URL ?? `http://localhost:${process.env.PORT ?? 3000}`;
}

export class BotManager {
  /**
   * @param {object} [opts]
   * @param {string} [opts.baseUrl]      REST+WS target (loopback when embedded).
   * @param {number} [opts.count]        customer/driver pairs to run (1..3, default 2 = CLI parity).
   * @param {"daemon"|"fast"} [opts.pace] daemon paces rides ~90s apart; fast is --once/--burst pacing.
   * @param {number} [opts.declineChance] overrides CONFIG.declineChance (fast pace forces 0).
   * @param {(action: string, detail?: string) => void} [opts.log]
   */
  constructor({
    baseUrl = defaultBaseUrl(),
    count = 2,
    pace = "daemon",
    declineChance,
    log = defaultLog,
  } = {}) {
    this.baseUrl = baseUrl;
    this.customers = CONFIG.customers.slice(0, Math.max(1, Math.min(3, count)));
    this.drivers = CONFIG.drivers.slice(0, this.customers.length);
    this.pace = pace;
    // Fast modes exist for deterministic screenshots/verification ("--burst N
    // → N completed"), so the daemon-only 15% decline variety is off there.
    this.declineChance =
      pace === "fast" ? 0 : (declineChance ?? CONFIG.declineChance);
    this.log = log;

    this.startedAt = null;
    this.stoppedAt = null;
    this.ridesSpawned = 0;
    this.lastRideAt = null;
    this.completedRides = 0;
    this.stepDelay =
      pace === "fast" ? CONFIG.fastStepDelayMs : CONFIG.daemonStepDelayMs;
    this.accounts = [];
    this.registry = {
      rides: new Map(), // rideId -> {customerToken, driverToken, label}
      stopping: false,
      add: (id, info) => {
        this.registry.rides.set(id, {
          ...(this.registry.rides.get(id) ?? {}),
          ...info,
        });
      },
    };
    this.rideTimer = null;
    this.riderIdx = 0;
    this.running = false;
  }

  async api(method, path, { token, body } = {}) {
    const res = await fetch(this.baseUrl + path, {
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

  randomPoint() {
    const { latMin, latMax, lngMin, lngMax } = CONFIG.bounds;
    return {
      lat: Number(rand(latMin, latMax).toFixed(6)),
      lng: Number(rand(lngMin, lngMax).toFixed(6)),
    };
  }

  walk(pos) {
    const clamp = (v, lo, hi) => Number(Math.min(hi, Math.max(lo, v)).toFixed(6));
    return {
      lat: clamp(pos.lat + rand(-0.0015, 0.0015), CONFIG.bounds.latMin, CONFIG.bounds.latMax),
      lng: clamp(pos.lng + rand(-0.0015, 0.0015), CONFIG.bounds.lngMin, CONFIG.bounds.lngMax),
    };
  }

  // -------------------------------------------------------------------------
  // Bootstrap — idempotent account/profile/verification setup for bots only.
  // -------------------------------------------------------------------------

  // Deck cards show a tinder-style photo pager, so bots carry vehicle photos
  // too: two CC-licensed moto shots fetched from the Openverse API and pushed
  // through POST /api/drivers/photos. Any trouble here is cosmetic — warn and
  // continue, never crash the demo on photo business.
  async ensureAccount({ email, name, phone }, role) {
    try {
      const data = await this.api("POST", "/api/register", {
        body: { name, phone, email, password: CONFIG.password, role },
      });
      this.log("registered", `${role} ${email}`);
      return data.token;
    } catch {
      const data = await this.api("POST", "/api/login", {
        body: { email, password: CONFIG.password },
      });
      return data.token;
    }
  }

  /** First CC image URL for a query, or null when the search comes back empty. */
  async firstPhotoUrl(query) {
    const res = await fetch(
      `https://api.openverse.org/v1/images/?q=${encodeURIComponent(query)}&license_type=all-cc&page_size=5`,
    );
    if (!res.ok) throw new Error(`openverse HTTP ${res.status} for "${query}"`);
    const json = await res.json();
    return json.results?.[0]?.url ?? null;
  }

  /** Image bytes as a Blob, or throws unless jpeg/png/webp within the 5MB cap. */
  async downloadPhoto(url) {
    const PHOTO_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
    const PHOTO_MAX_BYTES = 5 * 1024 * 1024; // mirrors the server's upload cap
    const res = await fetch(url);
    if (!res.ok) throw new Error(`image HTTP ${res.status}: ${url}`);
    const type = res.headers.get("content-type")?.split(";")[0];
    if (!PHOTO_TYPES.has(type)) throw new Error(`unacceptable type ${type}: ${url}`);
    const bytes = Buffer.from(await res.arrayBuffer());
    if (bytes.length === 0 || bytes.length > PHOTO_MAX_BYTES) {
      throw new Error(`unacceptable size ${bytes.length}B: ${url}`);
    }
    return new Blob([bytes], { type });
  }

  /** Multipart POST /api/drivers/photos — same envelope rules as api(). */
  async uploadPhotos(token, blobs) {
    const form = new FormData();
    for (const [i, blob] of blobs.entries()) form.append("photos", blob, `vehicle${i}.jpg`);
    const res = await fetch(this.baseUrl + "/api/drivers/photos", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
      body: form,
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok || json.success === false) {
      const err = new Error(json?.error?.message ?? `HTTP ${res.status} /api/drivers/photos`);
      err.code = json?.error?.code ?? `HTTP_${res.status}`;
      throw err;
    }
    return json.data;
  }

  /** Idempotent: fill an empty bot gallery with one photo per query; warn+continue on failure. */
  async ensureVehiclePhotos(d, row) {
    if ((row.vehicle_photos?.length ?? 0) > 0) {
      this.log("vehicle photos present", `${d.email} (${row.vehicle_photos.length})`);
      return;
    }
    try {
      const queries = ["motodop phnom penh", "moto delivery cambodia"];
      const blobs = [];
      for (const query of queries) {
        const url = await this.firstPhotoUrl(query);
        if (!url) throw new Error(`no openverse result for "${query}"`);
        blobs.push(await this.downloadPhoto(url));
      }
      const updated = await this.uploadPhotos(d.token, blobs);
      this.log("vehicle photos uploaded", `${d.email}: ${updated.vehicle_photos.join(", ")}`);
    } catch (err) {
      this.log("vehicle photos skipped", `${d.email}: ${err.message}`);
    }
  }

  async bootstrap() {
    const customerTokens = [];
    for (const c of this.customers) {
      customerTokens.push(await this.ensureAccount(c, "customer"));
    }

    const driverAccounts = [];
    for (const d of this.drivers) {
      driverAccounts.push({ ...d, token: await this.ensureAccount(d, "driver") });
    }

    // Vehicle profile: create-once server-side; "already exists" is success.
    for (const d of driverAccounts) {
      try {
        await this.api("POST", "/api/drivers", {
          token: d.token,
          body: {
            car_model: pick(["Honda Dream", "Yamaha Sirius", "Honda Wave", "Suzuki Smash"]),
            plate: `PP-${Math.floor(rand(1000, 9999))}`,
            license_no: `L-${Math.floor(rand(10000, 99999))}`,
            price_per_km: Number(rand(1.0, 1.5).toFixed(2)),
          },
        });
        this.log("profile created", d.email);
      } catch (err) {
        if (err.code !== "VALIDATION_ERROR") throw err;
      }
    }

    // Admin verifies each bot driver (drivers-row PK comes from the admin list,
    // matched by email — bots never appear in seeded data so matching is safe).
    const adminToken = (
      await this.api("POST", "/api/login", {
        body: { email: CONFIG.admin.email, password: CONFIG.admin.password },
      })
    ).token;

    const rows = await this.api("GET", "/api/admin/drivers", { token: adminToken });
    for (const d of driverAccounts) {
      const row = rows.find((r) => r.email === d.email);
      if (!row) throw new Error(`no drivers row found for ${d.email}`);
      d.driverId = row.driver_id;
      d.userId = row.user_id;
      if (!row.verified) {
        await this.api("POST", `/api/admin/drivers/${row.driver_id}/verify`, { token: adminToken });
        this.log("verified by admin", d.email);
      }
      d.pos = this.randomPoint();
      // Photos land while still offline so the first nearby card already paginates.
      await this.ensureVehiclePhotos(d, row);
      await this.api("PATCH", "/api/drivers/online", {
        token: d.token,
        body: { online: true, ...d.pos },
      });
    }

    return { customerTokens, driverAccounts };
  }

  // -------------------------------------------------------------------------
  // Shutdown — settles every tracked ride and offlines every bot driver.
  // -------------------------------------------------------------------------

  async settleRide(rideId, { customerToken, driverToken } = {}) {
    let status = null;
    try {
      // Either participant may read the ride — socket-triggered entries (rides
      // booked by an external customer onto a bot driver) carry no customerToken.
      status = (await this.api("GET", `/api/rides/${rideId}`, { token: customerToken ?? driverToken })).status;
    } catch {
      return;
    }
    try {
      if (status === "requested") {
        if (!customerToken) {
          // §2: drivers cannot cancel from requested — not our ride, leave it.
          this.log("cleanup skipped", `#${rideId} requested by an external customer — left untouched`);
          this.registry.rides.delete(rideId);
          return;
        }
        await this.api("POST", `/api/rides/${rideId}/cancel`, { token: customerToken });
        this.log("cleanup cancelled", `#${rideId}`);
      } else if (status === "accepted" && driverToken) {
        await this.api("POST", `/api/rides/${rideId}/start`, { token: driverToken });
        await this.api("POST", `/api/rides/${rideId}/start-ride`, { token: driverToken });
        await this.api("POST", `/api/rides/${rideId}/complete`, { token: driverToken });
        this.log("cleanup completed", `#${rideId}`);
      } else if (status === "en_route" && driverToken) {
        await this.api("POST", `/api/rides/${rideId}/start-ride`, { token: driverToken });
        await this.api("POST", `/api/rides/${rideId}/complete`, { token: driverToken });
        this.log("cleanup completed", `#${rideId}`);
      } else if (status === "in_progress" && driverToken) {
        await this.api("POST", `/api/rides/${rideId}/complete`, { token: driverToken });
        this.log("cleanup completed", `#${rideId}`);
      }
    } catch (err) {
      this.log("cleanup error", `#${rideId} ${err.code}: ${err.message}`);
    }
    this.registry.rides.delete(rideId);
  }

  async cleanup(drivers) {
    this.registry.stopping = true;
    for (const [id, info] of this.registry.rides) await this.settleRide(id, info);
    for (const d of drivers) {
      for (const t of d.timers ?? []) clearInterval(t);
      d.socket?.disconnect();
      try {
        await this.api("PATCH", "/api/drivers/online", { token: d.token, body: { online: false } });
        this.log("driver offline", d.email);
      } catch (err) {
        this.log("offline failed", `${d.email}: ${err.message}`);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Driver runtime — WS heartbeat + accept/(decline)/drive/rate state machine.
  // -------------------------------------------------------------------------

  /** Exactly-once gate: whichever trigger wins (socket event or customer call). */
  claimDrive(account, rideId) {
    if (account.busy || account.handled.has(rideId)) return false;
    account.handled.add(rideId);
    account.busy = true;
    this.registry.add(rideId, { driverToken: account.token });
    void this.driveRide(account, rideId);
    return true;
  }

  async driveRide(account, rideId) {
    // Once stopping, cleanup owns the ride — bail instead of racing it.
    const guard = () => !this.registry.stopping;
    try {
      if (guard() && Math.random() < this.declineChance) {
        await this.api("POST", `/api/rides/${rideId}/decline`, { token: account.token });
        this.log("ride declined", `#${rideId} (variety path)`);
      } else {
        if (!guard()) return;
        await this.api("POST", `/api/rides/${rideId}/accept`, { token: account.token });
        this.log("ride accepted", `#${rideId}`);
        await sleep(randIn(this.stepDelay));
        if (!guard()) return;
        await this.api("POST", `/api/rides/${rideId}/start`, { token: account.token });
        this.log("driver en route", `#${rideId}`);
        await sleep(randIn(this.stepDelay));
        if (!guard()) return;
        await this.api("POST", `/api/rides/${rideId}/start-ride`, { token: account.token });
        this.log("ride started", `#${rideId}`);
        await sleep(randIn(this.stepDelay));
        if (!guard()) return;
        await this.api("POST", `/api/rides/${rideId}/complete`, { token: account.token });
        this.log("ride completed", `#${rideId}`);
        this.completedRides++;
        const stars = pick([4, 5]);
        await this.api("POST", `/api/rides/${rideId}/rate`, { token: account.token, body: { stars } });
        this.log(`driver rated ${stars}*`, `#${rideId}`);
      }
    } catch (err) {
      this.log("driver error", `#${rideId} ${err.code}: ${err.message}`);
    } finally {
      account.busy = false;
    }
  }

  startDriver(account) {
    account.busy = false;
    account.handled = new Set(); // ride ids already claimed by either trigger
    const socket = io(this.baseUrl, {
      transports: ["websocket"],
      auth: { token: account.token },
    });
    account.socket = socket;

    socket.on("connect", () => this.log("driver online", account.email));
    socket.on("connect_error", (err) => this.log("driver socket error", `${account.email}: ${err.message}`));

    // The server announces ride:requested as soon as the row commits — possibly
    // before the customer's POST response arrives. Both triggers funnel into
    // claimDrive, which is exactly-once per ride id.
    socket.on("ride:requested", (evt) => this.claimDrive(account, evt.rideId));

    // Heartbeat: WS location:update stamps updated_at; periodic REST online
    // refresh is belt-and-braces freshness if the socket ever drops.
    account.timers = [
      setInterval(() => {
        account.pos = this.walk(account.pos);
        socket.emit("location:update", account.pos);
        this.log("heartbeat", `${account.email} @ ${account.pos.lat},${account.pos.lng}`);
      }, CONFIG.heartbeatMs),
      setInterval(() => {
        this.api("PATCH", "/api/drivers/online", {
          token: account.token,
          body: { online: true, ...account.pos },
        }).catch((err) => this.log("online refresh failed", err.message));
      }, CONFIG.onlineRefreshMs),
    ];
  }

  // -------------------------------------------------------------------------
  // Customer side — book nearest free BOT driver, wait for terminal status,
  // rate if completed. Resolves with the ride result (or null if nothing booked).
  // -------------------------------------------------------------------------

  async runRide(label, customerToken) {
    const c = this.randomPoint();
    const nearby = await this.api(
      "GET",
      `/api/drivers/nearby?lat=${c.lat}&lng=${c.lng}`,
      { token: customerToken },
    );
    // Bots book bot drivers only (hygiene rule).
    const target = nearby.find((card) =>
      this.accounts.some((d) => d.driverId === card.id && !d.busy),
    );
    if (!target) {
      this.log(
        "no bookable bot driver",
        `${nearby.length} nearby card(s), ${this.accounts.filter((d) => !d.busy).length} bot(s) free`,
      );
      return null;
    }

    const dropoff = this.randomPoint();
    const ride = await this.api("POST", "/api/rides", {
      token: customerToken,
      body: {
        driverId: target.id,
        pickup: { ...c, address: "Bot pickup, Phnom Penh" },
        dropoff: { ...dropoff, address: "Bot dropoff, Phnom Penh" },
      },
    });
    const driver = this.accounts.find((d) => d.driverId === target.id);
    this.registry.add(ride.id, { customerToken, driverToken: driver?.token, label });
    this.ridesSpawned++;
    this.lastRideAt = new Date().toISOString();
    this.log("ride booked", `#${ride.id} by ${label} → ${target.name} (${target.car_model})`);

    // Trigger the booked driver directly — the socket announcement may land
    // before this POST response does; claimDrive makes both exactly-once.
    this.claimDrive(driver, ride.id);

    // Sockets announce; REST is the source of truth — poll to terminal state.
    const terminal = ["completed", "cancelled", "declined"];
    let status = "requested";
    const deadline = Date.now() + 45_000;
    while (!terminal.includes(status) && Date.now() < deadline) {
      await sleep(400);
      try {
        status = (await this.api("GET", `/api/rides/${ride.id}`, { token: customerToken })).status;
      } catch {
        break;
      }
    }

    if (status === "completed") {
      const stars = pick([4, 5]);
      await this.api("POST", `/api/rides/${ride.id}/rate`, { token: customerToken, body: { stars } });
      this.log(`customer rated ${stars}*`, `#${ride.id}`);
    }
    this.registry.rides.delete(ride.id);
    this.log("ride settled", `#${ride.id} final=${status}`);
    return { id: ride.id, status };
  }

  /** One ride attempt through the round-robin customer rotation. */
  async launchRide() {
    const idx = this.riderIdx % this.customerTokens.length;
    this.riderIdx++;
    const label = `c${idx + 1}`;
    try {
      return await this.runRide(label, this.customerTokens[idx]);
    } catch (err) {
      this.log("ride error", `${label}: ${err.code}: ${err.message}`);
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Lifecycle — start/stop/runRides/status, shared by both hosts.
  // -------------------------------------------------------------------------

  /** Bootstrap + drivers online (+ arm the daemon ride loop). Idempotent-safe. */
  async start() {
    if (this.running) return this.status();
    this.log("bootstrapping", this.baseUrl);
    const { customerTokens, driverAccounts } = await this.bootstrap();
    this.customerTokens = customerTokens;
    this.accounts = driverAccounts;
    this.log(
      "bootstrap done",
      `${customerTokens.length} customers · ${driverAccounts.length} drivers verified+online`,
    );

    for (const d of driverAccounts) this.startDriver(d);
    await sleep(500); // let sockets connect before the first booking

    this.registry.stopping = false;
    this.startedAt = Date.now();
    this.stoppedAt = null;
    this.running = true;

    if (this.pace === "daemon") {
      this.log("started", `embedded daemon, rides every ~${CONFIG.rideEveryMs / 1000}s`);
      this.armRideLoop();
    } else {
      this.log("started", "fast pace (no ride loop — use runRides)");
    }
    return this.status();
  }

  armRideLoop() {
    const tick = async () => {
      this.rideTimer = null;
      if (!this.running) return;
      await this.launchRide();
      this.log("daemon idle", `${this.completedRides} completed so far`);
      if (this.running) {
        this.rideTimer = setTimeout(tick, CONFIG.rideEveryMs * rand(0.85, 1.15));
      }
    };
    this.rideTimer = setTimeout(tick, CONFIG.rideEveryMs * rand(0.85, 1.15));
  }

  /**
   * Sequential back-to-back rides (fast pace: --once / --burst semantics).
   * Aborts on the first failed launch; returns completed counts for exit codes.
   */
  async runRides(total) {
    let completed = 0;
    let failed = false;
    for (let i = 0; i < total; i++) {
      const result = await this.launchRide(); // sequential = race-free
      if (!result) {
        failed = true;
        break;
      }
      if (result.status === "completed") completed++;
    }
    return { completed, failed };
  }

  /** Offlines drivers, closes sockets, settles rides (the SIGINT path). */
  async stop() {
    if (!this.running && !this.accounts.length) return this.status();
    if (this.rideTimer) {
      clearTimeout(this.rideTimer);
      this.rideTimer = null;
    }
    this.registry.stopping = true;
    this.running = false;
    this.log("shutting down", `${this.completedRides} completed ride(s) this session`);
    await this.cleanup(this.accounts);
    this.stoppedAt = Date.now();
    return this.status();
  }

  /**
   * Session snapshot. After stop() the numbers freeze (last session's record)
   * and drivers clears — live driver state comes from the DB via the admin
   * endpoints, not from this in-memory registry.
   */
  status() {
    const end = this.stoppedAt ?? Date.now();
    return {
      running: this.running,
      uptimeSec: this.startedAt ? Math.max(0, Math.floor((end - this.startedAt) / 1000)) : 0,
      ridesSpawned: this.ridesSpawned,
      lastRideAt: this.lastRideAt,
      emails: this.accounts.map((d) => d.email),
    };
  }
}

// ---------------------------------------------------------------------------
// Embedded singleton — the server-side handle behind /api/admin/bots. Off by
// default: nothing here runs until startEmbeddedBots is called.
// ---------------------------------------------------------------------------

let embedded = null;

export function embeddedBotsStatus() {
  return embedded
    ? embedded.status()
    : { running: false, uptimeSec: 0, ridesSpawned: 0, lastRideAt: null, emails: [] };
}

/**
 * Starts the embedded manager (idempotency is the caller's concern — a second
 * start while running throws BOT_ALREADY_RUNNING so admins get an explicit
 * conflict instead of a silent success pretending to be fresh).
 */
export async function startEmbeddedBots({ count = 2 } = {}) {
  if (embedded) {
    const err = new Error("Bots manager is already running");
    err.code = "BOT_ALREADY_RUNNING";
    throw err;
  }
  const manager = new BotManager({ count });
  await manager.start();
  embedded = manager;
  return manager.status();
}

/** Stops and discards the embedded manager; safe when nothing is running. */
export async function stopEmbeddedBots() {
  if (!embedded) return embeddedBotsStatus();
  const manager = embedded;
  embedded = null;
  await manager.stop();
  return manager.status();
}
