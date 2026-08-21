# IMPLEMENTATION.md — MotoDub build tasks

> **How to use this file:** execute tasks **strictly in order**, one at a time. Each
> task is self-contained: Objective · Files · Steps · Verify · Commit. Run the Verify
> commands and paste real output into the report. **CHECKPOINT** tasks = do the code
> part, then STOP and hand the manual step to Seth — never skip or fake one.
> Workflow + ground rules live in **AGENTS.md** · project facts (accounts, environment, commands) in **PROJECT.md** (read both first).
> Contracts: **ARCHITECTURE.md**.

Task key:
- 🛠 = code task · ⏸ = CHECKPOINT (Seth interaction required) · 📦 = commit after task

---

## Phase 0 — Foundation

### Task 0.0 — ⏸ Flutter toolchain
**Objective:** Flutter SDK working on the dev machine (not installed at plan time).

**Files:** none (environment).

**Steps:**
1. Install Flutter SDK (Android Studio route: SDK Manager → Flutter plugin; or standalone SDK per docs.flutter.dev).
2. Add `flutter` to PATH; run `flutter doctor` and accept Android licenses (`flutter doctor --android-licenses`).
3. Confirm versions.

**Verify:** `flutter --version` prints a stable build; `flutter doctor` shows Android toolchain ready (Java OK).
**Commit:** none (environment setup).

---

### Task 0.1 — 📦 Git init + repo skeleton
**Objective:** Git repo at `final-project/` with a clean starting tree.

**Files:**
- Create: `.gitignore` (root), `README.md` (one-liner + pointer to docs)

**Steps:**
1. `git init` (final-project/ is the root; commit ALL existing docs: IDEA.md, PLAN.md, ARCHITECTURE.md, AGENTS.md, PROJECT.md, IMPLEMENTATION.md, DESIGN.md).
2. `.gitignore` must include: `node_modules/`, `.env`, `.env.local`, `google-services.json`, `build/`, `.dart_tool/`, `*.iml`, `.idea/`, `.vscode/`, `android/.gradle/`, `*.apk`, `coverage/`.
3. `git add -A && git commit -m "chore: init repo with planning docs"`.

**Verify:** `git log --oneline` shows the init commit; `git status` clean.
**Commit:** `chore: init repo with planning docs`

---

### Task 0.2 — 📦 Server scaffold (Express + tests green)
**Objective:** `server/` boots on :3000 with a health endpoint and a working test setup.

**Files:**
- Create: `server/package.json`, `server/src/app.js`, `server/src/server.js`, `server/src/config/env.js`, `server/test/health.test.js`, `server/.env.example`, `server/.gitignore`

**Steps:**
1. `cd final-project && mkdir server && cd server && npm init -y`; set `"type": "module"`.
2. Install: `npm i express@5 socket.io mysql2 sequelize dotenv cors bcryptjs jsonwebtoken zod`; dev: `npm i -D nodemon jest supertest`.
3. `src/app.js` exports `createApp()` (express + cors + json) — **no listen**. `src/server.js` calls `createApp().listen(process.env.PORT ?? 3000)`.
4. `GET /health` returns `{ success: true, data: { status: "ok" } }`.
5. `env.js` loads dotenv and exports `{ PORT, DB_NAME, DB_USER, DB_PASS, DB_HOST, DB_PORT, JWT_SECRET }` with sane defaults (DB_PORT 3306).
6. `package.json` scripts: `dev: nodemon src/server.js`, `start: node src/server.js`, `test: jest`.
7. `health.test.js`: supertest asserts 200 + envelope shape.
8. Homepage route `GET /` → redirect to `/health` (avoids 404 confusion).

**Verify:** `npm test` → 1 passing. `npm run dev` → start, then `curl -s localhost:3000/health` returns `{"success":true,...}`.
**Commit:** `chore: scaffold express server with health endpoint`

---

### Task 0.3 — 📦 Database connected
**Objective:** MariaDB database exists and Sequelize connects.

**Files:**
- Create: `server/src/config/db.js` (sequelize instance from env), `server/src/scripts/dbcheck.js`, `.env` (local, gitignored), `.env.example` (committed)

**Steps:**
1. Create the database inside the existing MySQL 8.0 container (command in PROJECT.md §4 — `docker exec mysql_container mysql -uroot -p1234 -e "CREATE DATABASE motodub …"`).
2. `.env`: `PORT=3000`, `DB_NAME=motodub`, `DB_USER=root`, `DB_PASS=` (or local creds), `DB_HOST=127.0.0.1`, `DB_PORT=3306`, `JWT_SECRET=<long random hex>`.
3. `db.js` = `new Sequelize(DB_NAME, DB_USER, DB_PASS, { host, port, dialect: "mysql", logging: false })`.
4. `dbcheck.js` runs `sequelize.authenticate()` and prints `connected`.
5. Add script `"db:check": "node src/scripts/dbcheck.js"`.

**Verify:** `npm run db:check` prints `connected` (real output).
**Commit:** `chore: wire sequelize to local database`

---

### Task 0.4 — 📦 Flutter scaffold with locked applicationId
**Objective:** `app/` created with applicationId `com.pu.motodub` and all planned dependencies.

**Files:**
- Create: `app/` via `flutter create`

**Steps:**
1. `cd final-project && flutter create --org com.pu --project-name motodub app`.
2. Confirm `applicationId "com.pu.motodub"` in `app/android/app/build.gradle(.kts)`. **This id is binding — do not change it later.**
3. Add deps: `flutter pub add dio socket_io_client flutter_map latlong2 flutter_riverpod go_router flutter_local_notifications google_fonts shared_preferences`.
4. Delete the counter-app demo body; leave a bare `MaterialApp` placeholder.
5. `flutter analyze` clean.

**Verify:** `flutter analyze` → no issues. Widget test (`flutter test`) passes with the placeholder.
**Commit:** `chore: scaffold flutter app (motodub)`

---

### Task 0.5 — 📦 App shell: theme + routes + role redirect stub
**Objective:** app boots to a login route; role placeholders exist.

**Files:**
- Create: `app/lib/main.dart`, `app/lib/app.dart` (MaterialApp + theme), `app/lib/core/theme/app_theme.dart`, `app/lib/core/router/app_router.dart`, placeholder screens under `app/lib/features/{auth,customer,driver,admin}/`

**Steps:**
1. `app_theme.dart`: implement tokens from **DESIGN.md §2–3** — Sora (headings) + Plus Jakarta Sans (body) via google_fonts, amber `#F59E0B` seed on `#FAFAF9`, ink `#111827`.
2. `app_router.dart`: go_router with routes `/login`, `/customer`, `/driver`, `/admin` → simple placeholder screens.
3. Redirect stub: not-authenticated → `/login` (auth state comes in Phase 1; stub returns false for now).
4. `main.dart` wires ProviderScope + MaterialApp.router.

**Verify:** `flutter analyze` clean; `flutter test` passes; ⏸ Seth runs on emulator (agent reports, Seth confirms boot).
**Commit:** `feat: app shell with theme, router and role placeholders`

---

## Phase 1 — Authentication

### Task 1.1 — 📦 User model + migration
**Objective:** `users` table exists per ARCHITECTURE §10.

**Files:**
- Create: `server/src/models/user.js`, migrations via sequelize-cli (`server/migrations/XXXX-create-users.js`), `server/src/config/config.js` (sequelize-cli config from env)

**Steps:**
1. Install `sequelize-cli` dev; init `.sequelizerc` pointing at `src/models`, `migrations/`, `seeders/`.
2. `User` model: `id, role ENUM('customer','driver','admin'), name, phone, email (unique), password_hash, photo (nullable), rating DECIMAL(2,1) default 5.0, active BOOL default true, fcm_token (nullable), timestamps`.
3. Migration creates the table with the same columns; `npm run migrate` applies it.

**Verify:** `npm run migrate` succeeds; `mariadb motodub -e "SHOW COLUMNS FROM users;"` lists expected columns.
**Commit:** `feat: users model and migration`

---

### Task 1.2 — 📦 Register + login endpoints (JWT)
**Objective:** `POST /api/register` and `POST /api/login` work end-to-end.

**Files:**
- Create: `server/src/routes/auth.routes.js`, `server/src/controllers/auth.controller.js`, `server/src/services/auth.service.js`, `server/src/utils/jwt.js`, `server/src/utils/envelope.js`, `server/src/middlewares/validate.js` (zod), `server/test/auth.test.js`

**Steps:**
1. `envelope.js`: `ok(data)` and `fail(code, message)` helpers producing the ARCHITECTURE §4 shape.
2. `auth.service.js`: register (zod-check name/phone/email/password ≥8, bcrypt hash, role from body — one of customer/driver/admin, duplicate email → `VALIDATION_ERROR`), login (verify email + password → JWT `{sub, role}` 30d via `jwt.sign`).
3. `validate.js` zod schema middleware; wire routes: `POST /api/register`, `POST /api/login`.
4. Tests (supertest): register success → `{success:true, data:{token, user}}`; duplicate email fails; login wrong password → `UNAUTHORIZED`.

**Verify:** `npm test` — auth tests pass.
**Commit:** `feat: register and login with jwt`

---

### Task 1.3 — 📦 Auth middleware + error handler
**Objective:** protected routes reject unauthenticated/wrong-role callers.

**Files:**
- Create: `server/src/middlewares/authenticate.js`, `server/src/middlewares/authorize.js`, `server/src/middlewares/errorHandler.js`, `server/test/authz.test.js`

**Steps:**
1. `authenticate`: parse `Authorization: Bearer <jwt>`, verify, attach `req.user = {id, role}`; else 401 `UNAUTHORIZED`.
2. `authorize(...roles)`: 403 `FORBIDDEN` if role not allowed.
3. `errorHandler`: any thrown error → envelope `{success:false, error:{code,message}}`, 500 fallback `INTERNAL`.
4. Wire both into `app.js` (auth on `/api`, error handler last).
5. Tests: no token → 401; customer calling a driver route → 403.

**Verify:** `npm test` — authz tests pass.
**Commit:** `feat: auth middleware and error handler`

---

### Task 1.4 — 📦 Flutter auth screens + role redirect  ⏸ (manual verify)
**Objective:** login/register UI working; after login the app lands on the right dashboard.

**Files:**
- Create: `app/lib/core/api/api_client.dart` (dio, base URL from `--dart-define API_BASE_URL`, default `http://10.0.2.2:3000`), `app/lib/core/api/auth_repo.dart`, `app/lib/features/auth/{login_screen,register_screen,providers}.dart`, `app/lib/core/auth/auth_state.dart` (token + role in shared_preferences)

**Steps:**
1. `api_client.dart`: dio instance + envelope interceptor → typed `ApiResult<T>` (success/error(code)).
2. Login/register screens: forms (name/phone/email/password + role picker on register), loading + error states (friendly message per error code).
3. `auth_state.dart` + riverpod `authProvider` (AsyncNotifier): login/register/logout, persist token+role.
4. go_router redirect: token? → route by role (`/customer`, `/driver`, `/admin`) : → `/login`. Add logout button on each shell placeholder.
5. Widget test: login screen renders + validation errors show.

**Verify:** `flutter test` + `flutter analyze` clean. ⏸ Seth: log in as `admin@taxi.demo / Admin@123` on the emulator → lands on the admin shell.
**Commit:** `feat: flutter auth flow with role routing`

---

## Phase 2 — Data layer

### Task 2.1 — 📦 Driver + Ride models/migrations
**Objective:** `drivers` and `rides` tables per ARCHITECTURE §10.

**Files:**
- Create: `server/src/models/driver.js`, `server/src/models/ride.js`, two migrations, association wiring in `server/src/models/index.js`

**Steps:**
1. `Driver`: `user_id FK→users`, `car_model, plate, license_no, verified (bool, default false), online (bool, default false), price_per_km DECIMAL(6,2), lat, lng DECIMAL(10,7), updated_at`.
2. `Ride`: `customer_id FK, driver_id FK, status ENUM('requested','accepted','declined','en_route','in_progress','completed','cancelled'), pickup_lat/lng/address, dropoff_lat/lng/address, fare DECIMAL NULL (reserved — NEVER set), customer_rating/driver_rating TINYINT NULL, timestamps`.
3. Associations: `Driver.belongsTo(User)`, `Ride.belongsTo(User, as 'customer')`, `Ride.belongsTo(User, as 'driver')`.
4. Migrations create both tables (+indexes on status, driver_id, customer_id).

**Verify:** `npm run migrate` applies; `SHOW COLUMNS` on both tables.
**Commit:** `feat: driver and ride models`

---

### Task 2.2 — 📦 Seeders (demo data)
**Objective:** idempotent seed producing the PROJECT.md §5 demo accounts.

**Files:**
- Create: `server/src/seeders/seed.js`, script `"seed"`, `"seed:reset"`

**Steps:**
1. Seed 6 users with bcrypt-hashed passwords; 3 drivers linked (dara verified+online, sophea verified+online, vuthy unverified); all drivers get lat/lng within ~2 km of Phnom Penh center (11.5564, 104.9282), asking rates 1.20 / 0.90 / 1.50, `updated_at` fresh.
2. 2 completed rides (srey ↔ dara, srey ↔ sophea) with ratings both sides.
3. Idempotent: `upsert`-style (find by email, update or create); `seed:reset` = `sequelize.sync({force:true})` + seed (dev only).

**Verify:** `npm run seed` twice — no duplicates; `SELECT role, email FROM users;` shows the 6 accounts.
**Commit:** `feat: demo seeders`

---

### Task 2.3 — 📦 Flutter models + repos
**Objective:** app-side `User`, `Driver`, `Ride` models mirror the API.

**Files:**
- Create: `app/lib/core/models/{user,driver,ride}.dart`, `app/lib/core/api/{driver_repo,ride_repo}.dart`, tests `app/test/models_test.dart`

**Steps:**
1. Models with `fromJson`/`toJson` matching API field names (camelCase ↔ snake_case mapping where needed).
2. `RideRepo` (create ride, actions by id, mine/history), `DriverRepo` (nearby, own profile, online toggle, vehicle create/update).
3. Unit tests: `fromJson` round-trip for each model; repo methods call the right dio path (mock adapter).

**Verify:** `flutter test` — model/repo tests pass; `flutter analyze` clean.
**Commit:** `feat: flutter models and repositories`

---

### Task 2.4 — 📦 API client polish: error mapping
**Objective:** every envelope error code maps to a friendly message and correct UI state.

**Files:**
- Create: `app/lib/core/api/error_messages.dart`, extend `api_client.dart`

**Steps:**
1. Map all codes from ARCHITECTURE §4 (`VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `RIDE_INVALID_TRANSITION`, `RIDE_BUSY_DRIVER`, `RIDE_BUSY_CUSTOMER`, `DRIVER_NOT_VERIFIED`) to user-friendly strings.
2. Timeout + network-failure handling → "Cannot reach server. Is the backend running?"

**Verify:** `flutter test` — mapping unit tests; manual curl against server for one error path.
**Commit:** `feat: api error mapping`

---

## Phase 3 — Customer swipe deck (the showpiece)

### Task 3.1 — 📦 Haversine utility
**Objective:** provably correct distance math used by nearby + ETA.

**Files:**
- Create: `server/src/utils/distance.js`, `server/test/distance.test.js`

**Steps:**
1. `haversineKm(lat1, lng1, lat2, lng2)` — great-circle distance in km.
2. `etaMinutes(distanceKm)` — `distance / 25` km/h city average, rounded up.

**Verify:** `npm test` — tests with known pairs: same point = 0; ~111 km per 1° latitude; PP → Siem Reap ≈ 250–270 km.
**Commit:** `feat: haversine distance utility`

---

### Task 3.2 — 📦 GET /api/drivers/nearby
**Objective:** customer's swipe deck source endpoint.

**Files:**
- Create: `server/src/routes/drivers.routes.js`, `server/src/controllers/driver.controller.js`, `server/src/services/driver.service.js`, `server/test/nearby.test.js`

**Steps:**
1. Query (customer only): `verified=true AND online=true` AND `updated_at` within 15s AND **no active ride** (NOT EXISTS a ride for this driver in `requested/accepted/en_route/in_progress`) — compute haversine to the given `lat, lng`, keep ≤ 10 km, sort by distance, limit 20.
2. Response per driver: id, name, photo, rating, car_model, plate, price_per_km, distance_km, eta_minutes.
3. Missing/invalid lat/lng → `VALIDATION_ERROR`.

**Verify:** `npm test` — seeded drivers appear for a PP-center query; unverified + offline drivers absent; busy driver absent.
**Commit:** `feat: nearby drivers endpoint`

---

### Task 3.3 — 📦 Driver card widget
**Objective:** a beautiful card: photo, name, rating, car, ETA, asking rate.

**Files:**
- Create: `app/lib/features/deck/driver_card.dart`, widgets test

**Steps:**
1. Build per **DESIGN.md §5 "Driver swipe card"**: Sora name headline 26/800 + rating chip (glass, amber star `#FCD34D`), car model + plate (Jakarta 600, white 85%), ETA chip (glass, white), asking-rate pill (amber bg, ink text).
2. Empty/invalid data → graceful fallback (no crash, show placeholders).
3. Test: renders all fields from a sample `Driver`.

**Verify:** `flutter test` — card renders fields.
**Commit:** `feat: driver card widget`

---

### Task 3.4 — 📦 Swipe deck component
**Objective:** THE gesture component — drag/fling = pass/book, stack pops.

**Files:**
- Create: `app/lib/features/deck/swipe_deck.dart`, `app/lib/features/deck/deck_provider.dart`, `app/test/swipe_deck_test.dart`

**Steps:**
1. `deckProvider`: loads `GET /drivers/nearby` (current location from device; fallback PP center), holds card list + `swipedLeft` set (local session only), exposes `swipeRight(driver)` / `swipeLeft(driver)`.
2. `swipe_deck.dart`: top card wrapped in `GestureDetector` — `onPanUpdate` drives `Transform.translate` + `Transform.rotate` (rotation ∝ drag distance); overlay fades in (green "BOOK" on right, red "PASS" on left); on release: if velocity or distance past threshold → animate off-screen + pop → next card; else spring back. **Math & curves from DESIGN.md §6**: rotate `dx/16deg`, release ≥ 110 px, spring-back `.35s cubic-bezier(.2,.8,.3,1.2)`, fly-out `.45s ease-in` ±640 px / ±34°. Stack z-order 10/9/8, peek scale `.945/.89` + `translateY 14/28`.
3. Show up to 3 stacked cards (peek behind). Empty deck → friendly empty state ("No drivers online right now — pull to refresh").
4. Backend calls: swipe-left = **local only**; swipe-right → Phase 3.5's repo call (wire the callback now; booking sheet comes next task).
5. Widget test: simulated fling triggers `onSwipedRight`; drag half-way + release springs back (no callback).

**Verify:** `flutter test` — fling + spring-back tests pass. ⏸ Seth: swipe feel on emulator — threshold tuning allowed (document tuned values in commit message).
**Commit:** `feat: swipe deck with fling detection`

---

### Task 3.5 — 📦 Booking confirm sheet
**Objective:** after a right-swipe, confirm pickup/dropoff and create the ride.

**Files:**
- Create: `app/lib/features/booking/booking_sheet.dart` (+ provider), extend `ride_repo.dart`

**Steps:**
1. Sheet opens with the driver card mini-header; `flutter_map` with pin placement: drag/ tap to set **pickup** and **dropoff** markers (dashed line between them, no routing API); free-text address fields editable.
2. Confirm button → `POST /api/rides` `{driverId, pickup{lat,lng,address}, dropoff{lat,lng,address}}` — payment fixed as cash (no UI choice; fare = not stored).
3. Server-side create already implied by ARCHITECTURE — implement in `RideService.create` (Phase 4.3 builds the full service; here a minimal `create` + `RIDE_BUSY_CUSTOMER` check is fine if Phase 4 hasn't landed — keep the controller behind the service interface).
4. Success → push `/tracking/{rideId}` placeholder; failure → error banner with mapped message (e.g. `RIDE_BUSY_DRIVER`).

**Verify:** `flutter test` — repo payload shape; manual: right-swipe → sheet → confirm → ride row in DB (`SELECT * FROM rides ORDER BY id DESC LIMIT 1;` status `requested`).
**Commit:** `feat: booking confirm sheet`

---

### Task 3.6 — ⏸ Deck + booking walkthrough
**Objective:** customer flow feels right on a real device.

**Steps:**
1. Seth runs app + server; logs in as `srey@taxi.demo`; swipes 2–3 drivers; books dara.
2. Signs in as `dara@taxi.demo` on the emulator/second device and sees the request (Phase 4 may be in flight — if not, verify via DB row + API).
3. Agent tunes: deck velocity threshold, card rotation factor, empty-state copy — only with Seth's sign-off.

**Verify:** clean swipe → confirm → ride row `requested`.
**Commit:** tuning commit only if values changed (`chore: tune deck thresholds`)

---

## Phase 4 — Driver side + realtime + push

### Task 4.1 — 📦 Driver endpoints (profile + online toggle)
**Objective:** driver can create vehicle profile (unverified), toggle online, update profile.

**Files:**
- Extend: `server/src/services/driver.service.js`, `driver.controller.js`, `routes`; tests `server/test/driver-profile.test.js`

**Steps:**
1. `POST /api/drivers` (driver-only): `car_model, plate, license_no, price_per_km` → creates Driver row, `verified=false`, linked to current user; create-once (409-ish → `VALIDATION_ERROR` if already exists).
2. `PATCH /api/drivers` — update own fields; `PATCH /api/drivers/online` — `{online: bool}`, sets `lat/lng` if provided, bumps `updated_at`.
3. Tests: driver role gates; unverified driver CAN toggle online (deck filters on verified — verified drivers only appear; unverified toggling online is allowed but invisible).

**Verify:** `npm test` passes.
**Commit:** `feat: driver profile and online toggle`

---

### Task 4.2 — 📦 RideService — the state machine
**Objective:** every rule in ARCHITECTURE §2 lives here, tested transition-by-transition.

**Files:**
- Create: `server/src/services/ride.service.js`, `server/test/ride-state-machine.test.js`

**Steps:**
1. `create(customer, {driverId, pickup, dropoff})` → `requested`; invariants: customer has no active ride (`RIDE_BUSY_CUSTOMER`), driver exists + verified + online (`DRIVER_NOT_VERIFIED` / `NOT_FOUND`), driver has no active ride (`RIDE_BUSY_DRIVER`).
2. `accept(driver, rideId)` → `accepted` (only the ride's driver; ride must be `requested`; driver-busy re-check → `RIDE_BUSY_DRIVER`).
3. `decline(driver, rideId)` → `declined` (own driver, `requested` only).
4. `cancel(actor, rideId)` → `cancelled` (customer: own, `requested|accepted|en_route`; driver: own, `accepted|en_route`; admin: any `in_progress` or earlier — emergency override).
5. `start(rideId)` → `en_route` (driver, from `accepted`); `startRide(rideId)` → `in_progress` (driver, from `en_route`); `complete(rideId)` → `completed` (driver, from `in_progress`).
6. `rate(actor, rideId, rating 1–5)` → sets `customer_rating`/`driver_rating`; only on `completed`; once per participant; updates the target user's average rating.
7. Every transition throws `RIDE_INVALID_TRANSITION` otherwise.

**Verify:** `npm test` — one test per transition + one per invariant (busy driver on double-accept, busy customer on double-create, customer cannot accept, rating twice fails, etc.).
**Commit:** `feat: ride state machine with invariants`

---

### Task 4.3 — 📦 Ride HTTP endpoints
**Objective:** the state machine is reachable via REST.

**Files:**
- Create: `server/src/routes/rides.routes.js` + controller; `server/test/ride-flow.test.js`

**Steps:**
1. Wire: `POST /api/rides`, `POST /api/rides/{id}/accept|decline|start|start-ride|complete|cancel`, `POST /api/rides/{id}/rate`, `GET /api/rides/mine`, `GET /api/rides/{id}` (permission: participants + admin).
2. RBAC per ARCHITECTURE §4 matrix.
3. Integration test (supertest): full happy path with seeded users — srey books dara → dara accepts → start → start-ride → complete → both rate; plus decline-path and cancel-path tests.

**Verify:** `npm test` — ride-flow suite green end-to-end against the real DB (test DB `motodub_test` created in test setup).
**Commit:** `feat: ride endpoints and integration flow`

---

### Task 4.4 — 📦 Socket.IO layer: handshake, rooms, events
**Objective:** live ride events reach the right clients.

**Files:**
- Create: `server/src/realtime/socket.js`, `server/src/realtime/events.js`; tests with two socket clients

**Steps:**
1. Attach socket.io to the same HTTP server; handshake = JWT from `auth.token` → join `user:{id}` room.
2. `emitRideRequested(ride)` → `user:{driverId}`; `emitRideAccepted(ride)` → `user:{customerId}` + `admin`; `emitRideDeclined(ride)` → `user:{customerId}`; `emitRideUpdated(ride)` → both participant rooms + `admin` (covers en_route/in_progress/completed/cancelled).
3. RideService/controller fires these after each successful transition (helper `notifyRide(ride)` in `realtime/`).
4. Test: connect two clients (customer + driver tokens), run the accept flow, assert each client received the right event with `{rideId, status}` payload.

**Verify:** `npm test` — socket event tests pass.
**Commit:** `feat: socket.io ride events with rooms`

---

### Task 4.5 — 📦 Location heartbeat + staleness
**Objective:** online drivers stream location; stale drivers drop out of the deck.

**Files:**
- Create: server `server/src/realtime/location.js` + `server/src/scripts/staleness-sweep.js`; app `app/lib/core/api/socket_client.dart`

**Steps:**
1. Server: `location:update {lat, lng}` (authenticated, driver role) → persist `drivers.lat/lng/updated_at`; broadcast `driver:location` to `location:{driverId}` room; customer joins that room when their ride is accepted (client side, Phase 5).
2. Staleness sweep: every 10s, flip `online=false` where `updated_at < NOW() - 15s`; nearby query also lazily requires `updated_at >= NOW() - 15s` (belt + suspenders per ARCHITECTURE §6).
3. App `socket_client.dart`: connects with JWT, auto-reconnect (socket_io_client), exposes typed streams; driver screen sends `location:update` every 5s while online (Phase 5.1 wires it visually).
4. Tests: stale driver excluded from nearby; sweep flips online flag.

**Verify:** `npm test`; manual: driver online → location rows update; stop heartbeats → within ~20s driver leaves the deck.
**Commit:** `feat: location heartbeat and staleness sweep`

---

### Task 4.6 — 📦 Driver request card + controls UI
**Objective:** the driver's working screen: requests, accept/decline, ride controls.

**Files:**
- Create: `app/lib/features/driver/driver_home_screen.dart`, `app/lib/features/driver/request_card.dart`, `app/lib/features/driver/ride_controls.dart`, `driver_provider.dart`

**Steps:**
1. Driver home: online/offline switch (calls `PATCH /drivers/online`; starts/stops heartbeats), vehicle-info card (from `PATCH /drivers` — first-time setup form if no profile).
2. Request card (rides in `requested` for me, via socket `ride:requested`): customer name/rating, pickup → dropoff, distance; **Accept** (green) / **Decline** (red) buttons.
3. Ride controls per state: `accepted` → "On my way"; `en_route` → "Start ride"; `in_progress` → "End ride" — each a button firing the endpoint + optimistic UI on socket `ride:updated`.
4. Widget tests: request card renders; buttons dispatch the right repo actions.

**Verify:** `flutter test` + `flutter analyze`. Manual (paired): customer books → driver screen shows card → Accept → both apps move to tracking state.
**Commit:** `feat: driver request and ride control UI`

---

### Task 4.7 — 📦 FCM: server sender + app receiver  ⏸ (Firebase console steps are Seth's)
**Objective:** backgrounded/closed app rings on ride events; dedupe with socket.

**Files:**
- Server: `server/src/push/fcm.js`, `POST /api/users/fcm-token` route; `.env` → `FIREBASE_SERVICE_ACCOUNT` (path)
- App: `app/lib/core/push/fcm_service.dart`; `google-services.json` at `app/android/app/`

**Steps:**
1. ⏸ **Seth** (30 min, can run while agent continues elsewhere): create Firebase project → register Android app **package `com.pu.motodub`** → download `google-services.json` → place at `app/android/app/google-services.json` → create service-account JSON → path into `server/.env`.
2. Server: `firebase-admin` init from service account; `sendPush(userId, {title, body, rideId})` — lookup `users.fcm_token`, send, log-and-ignore failures (socket still delivers foreground).
3. Call `sendPush` alongside every ride event (requested→driver, accepted→customer+admin, declined→customer, updated→participants).
4. `POST /api/users/fcm-token` (authenticated) stores the token.
5. App: `firebase_messaging` + `flutter_local_notifications`; register token post-login; foreground → local notification; background/terminated tap → go_router deep-link to `/tracking/{rideId}`.
6. **Dedupe:** any ride notification carries `rideId`; if the socket already delivered that event for the same ride, suppress the duplicate notification (map by rideId + status).

**Verify:** `npm test` (fcm-token route); ⏸ Seth: background the driver's phone → customer books → phone rings; tap → lands on the ride.
**Commit:** `feat: fcm push with socket dedupe`

---

## Phase 5 — Trip tracking

### Task 5.1 — 📦 Customer tracking screen
**Objective:** live map + status stepper after a match.

**Files:**
- Create: `app/lib/features/tracking/tracking_screen.dart`, `tracking_provider.dart`

**Steps:**
1. Route `/tracking/{rideId}`: `flutter_map` with pickup + dropoff markers, dashed pickup→dropoff line; **live driver marker** from `driver:location` on `location:{driverId}` (join room when ride accepted).
2. Status stepper: requested → accepted → en_route → in_progress → completed with labels; driven by `rideProvider` (REST fetch + socket `ride:updated` merge).
3. Driver info card (car, plate, phone) once `accepted`; cancel button enabled per state rules (customer: requested/accepted/en_route).
4. On `completed` → transition to rating screen (Phase 7 hook — stub route now).

**Verify:** `flutter test` — provider state transitions; manual paired run: marker moves when driver heartbeats.
**Commit:** `feat: customer tracking screen`

### Task 5.2 — 📦 History endpoints + screens
**Objective:** both roles see their ride history.

**Files:**
- Extend: `GET /api/rides/mine` (per-role view), `server/test` additions; app `app/lib/features/rides/history_screen.dart`

**Steps:**
1. `rides/mine`: customers see rides where they're customer; drivers where they're driver; include opposite-party name/rating snapshot + status badge + timestamps.
2. History screen: list with status colors (completed green, cancelled grey, declined red), pull-to-refresh, empty state.
3. Tests: seeded completed rides appear for srey and dara.

**Verify:** `npm test`; `flutter test` + analyze.
**Commit:** `feat: ride history`

---

## Phase 6 — Admin dashboard

### Task 6.1 — 📦 Admin endpoints
**Objective:** stats, driver management, ride feed data.

**Files:**
- Create: `server/src/routes/admin.routes.js`, `server/src/services/stats.service.js`, tests

**Steps:**
1. `GET /api/admin/stats` — today's rides, completed count, online drivers, avg rating, current `requested` count.
2. `GET /api/admin/drivers` — all drivers w/ verified/online/rating/asking-rate; `POST /api/admin/drivers/{id}/verify` (set verified=true) / `suspend` (active=false — and force-offline rides? no: suspend blocks future requests; add invariant: suspended driver cannot be booked (`DRIVER_NOT_VERIFIED` class → reuse `FORBIDDEN`)).
3. `GET /api/admin/rides` — all rides, filter by status, sort newest.
4. All admin-only (`authorize('admin')`); tests prove blocking other roles.

**Verify:** `npm test` — admin suite green; seeded data appears in stats.
**Commit:** `feat: admin endpoints`

### Task 6.2 — 📦 Admin screens
**Objective:** KPI cards, driver verification table, live ride feed.

**Files:**
- Create: `app/lib/features/admin/{admin_screen,dashboard_tab,drivers_tab,rides_tab}.dart`

**Steps:**
1. Dashboard tab: KPI cards (riverpod FutureProviders) — live rides, online drivers, today completed, avg rating.
2. Drivers tab: table/list — verify-status chip, approve / suspend buttons (**modal dialog** before destructive actions, per PROJECT.md §6).
3. Rides tab: status-filterable list, auto-refreshes via `admin` room socket (`ride:updated` appends).
4. Tests: widgets render seeded data through mocked repos.

**Verify:** `flutter test` + analyze. ⏸ Seth: approve `vuthy@taxi.demo`, watch his status flip, suspend and re-verify.
**Commit:** `feat: admin dashboard`

### Task 6.3 — optional stretch (only if on schedule)
**Objective:** admin live map of online drivers.

**Files:** `app/lib/features/admin/live_map_tab.dart`
**Steps:** flutter_map + periodic `GET /api/admin/drivers` (or admin-room location broadcast) → pins for online drivers with tooltips.

**Verify:** ⏸ Seth walks through all three admin tabs.
**Commit:** `feat: admin live map (stretch)`

---

## Phase 7 — Ratings, history polish, design pass

### Task 7.1 — 📦 Rating screens
**Objective:** both parties rate after `completed`.

**Files:**
- App: `app/lib/features/rides/rating_screen.dart` (stars 1–5, tap-to-select, submit)

**Steps:**
1. Auto-navigate to rating on `completed` (customer and driver views); submit → `POST /api/rides/{id}/rate`; disable once rated (server enforces once-per-participant).
2. Show the other party's name/photo; loading + thanks state.
3. Tests: widget renders, repo call shape.

**Verify:** `flutter test`; paired manual run: completed ride → both rate → ratings reflect in profiles.
**Commit:** `feat: rating screens`

### Task 7.2 — 📦 Polish pass: states, empty screens, design tokens
**Objective:** nothing in the demo can look broken or blank.

**Files:** app-wide (`app/lib/shared/`, theme)

**Steps:**
0. Audit all screens against **DESIGN.md** (§5 components, §6 motion, §9 states); fix mismatches first.
1. Every list/screen: loading skeleton, error state w/ retry, empty state (Sora-styled copy).
2. Deck: keep tuned thresholds; add subtle card shadow + parallax peek.
3. Full `flutter analyze` + `flutter test` green; `flutter test --coverage` recorded (no threshold gate).

**Verify:** analyze + tests green; ⏸ Seth walks every screen for 10 minutes, lists polish nits → fix all agreed ones.
**Commit:** `feat: design polish pass`

---

## Phase 8 — Demo prep

### Task 8.1 — 📦 Demo script + seed reset
**Objective:** a rehearsable, scripted demo.

**Files:**
- Create: `DEMO.md` (root), extend seeders if needed

**Steps:**
1. Write DEMO.md: exact sequence — happy path (srey books dara, full ride, rating), driver-declines path (vithy... note vuthy unverified → use sophea declining), customer-cancel path, FCM money shot (backgrounded device rings), admin verify flow (approve vuthy).
2. `npm run seed:reset` before each rehearsal for a clean state.
3. Demo accounts sheet (PROJECT.md §5) reprinted in DEMO.md.

**Verify:** dry-runs of every scripted path against a fresh seed — all green (timeboxed by Seth).
**Commit:** `docs: demo script`

### Task 8.2 — 📦 Two-device networking + APK
**Objective:** demo runs on TWO real devices against one backend.

**Files:** `app/` build config

**Steps:**
1. Firewall: allow 3000 on the laptop (record exact command used in DEMO.md).
2. Build: `flutter build apk --debug --dart-define=API_BASE_URL=http://<LAN-IP>:3000` (debug build keeps FCM simple) → `app/build/app/outputs/flutter-apk/app-debug.apk`.
3. Install on phone + emulator; same WiFi; verify customer (phone) ↔ driver (emulator) live pairing; check FCM ring on the backgrounded device.

**Verify:** ⏸ Seth: full cross-device happy path — phone + emulator — including backgrounded push.
**Commit:** `chore: two-device demo config notes`

### Task 8.3 — 📦 README
**Objective:** anyone (teacher) can run the project from scratch.

**Files:** `README.md` (root)

**Steps:**
1. Prereqs (Node 22, Flutter, MariaDB), DB create command, server run/test/migrate/seed, app run with both `API_BASE_URL` variants, demo accounts table, pointer to DEMO.md + docs.

**Verify:** Seth follows README cold on a clean checkout (timeboxed) — nothing missing.
**Commit:** `docs: project readme`

### Task 8.4 — ⏸ Final dress rehearsal
**Objective:** the exact demo-day script runs top to bottom, twice.

**Steps:**
1. `seed:reset` → run DEMO.md happy path end-to-end on two devices.
2. Repeat with the decline + cancel paths; then the FCM money shot.
3. Capture screenshots/video of: deck, tracking, driver request, admin dashboard (for the submission).

**Verify:** Seth declares the demo runnable, twice in a row, no dead ends. Project is submission-ready.

---

## Task index (for progress tracking)

| Phase | Tasks | Checkpoints |
|---|---|---|
| 0 Foundation | 0.0–0.5 | 0.0 toolchain · 0.5 emulator boot |
| 1 Auth | 1.1–1.4 | 1.4 role routing on device |
| 2 Data layer | 2.1–2.4 | — |
| 3 Deck | 3.1–3.6 | 3.6 deck feel |
| 4 Driver + realtime + FCM | 4.1–4.7 | 4.7 Firebase setup + phone ring |
| 5 Tracking | 5.1–5.2 | — |
| 6 Admin | 6.1–6.3 | 6.2 verify flow |
| 7 Polish | 7.1–7.2 | 7.2 walkthrough |
| 8 Demo prep | 8.1–8.4 | 8.4 dress rehearsal |

**Completion rule:** a phase is done when every task in it has its verification output recorded and every CHECKPOINT has Seth's sign-off.