# ARCHITECTURE.md — Tinder-Style Taxi Booking (v1)

> The complete technical architecture. **PLAN.md** = what we build, in what order.
> **This file** = how the parts behave, and the contracts between them.
> All decisions locked with Seth, 2026-08-20.

**Decision log (locked):**
| # | Decision | Chosen |
|---|----------|--------|
| 1 | Roles | customer (passenger), user (driver), admin — one Flutter app, role-routed |
| 2 | Backend | Node.js + Express + Socket.IO + MySQL (Sequelize), JWT auth, one process |
| 3 | Matching | Direct request to the ONE driver on the swiped card (true Tinder model) |
| 4 | Request lifetime | No expiry timer — waits for driver response; customer can cancel anytime |
| 5 | Notifications | Socket.IO (foreground) **+ FCM push** (background/closed), deduped |
| 6 | Fare | Negotiated offline in person — **never stored**; `fare` column reserved (NULL) |
| 7 | Card price hint | Driver card shows "asking rate" (`price_per_km`) as negotiation starting point |
| 8 | Payment | Cash on arrival — **wallet dropped entirely** |
| 9 | Map | flutter_map + OpenStreetMap (no API key) |
| 10 | App stack | Flutter (teacher requirement) · dio · socket_io_client · riverpod · go_router |

**Golden rule:** the backend owns every rule (state machine, permissions). The app is a
pretty remote control — it never computes state, it asks. That's why two phones always agree.

---

## 1. System parts

```
┌──────────────────────┐   REST (dio + JWT)    ┌───────────────────────────┐   SQL  ┌──────────┐
│  Flutter app (1 APK) │─────────────────────►│  Node.js process (:3000)  │───────►│  MySQL   │
│  customer / driver / │                      │  Express (HTTP)           │        │  users   │
│  admin UI by role    │◄─────────────────────│  Socket.IO (WS, same port)│        │  drivers │
│                      │   WS (live events)   │  ─ one process            │        │  rides   │
│  dio / socket_io /   │◄─────────────────────│  ─ business rules live    │        └──────────┘
│  riverpod / map      │   FCM (push)         │    here                   │
└──────────────────────┘                      └─────────────┬─────────────┘
       ▲    │  device token,                 firebase-admin │  send push
       │    └──────────────────────────────►┌───────────────▼──────────────┐
       └────────────────────────────────────│  Firebase Cloud Messaging     │
                                            │  (background/closed app only) │
                                            └───────────────────────────────┘
```

## 2. Ride state machine — the heart

All transitions flow through **one** service (`RideService`) that enforces the rules.

| From | To | Actor | Trigger (endpoint) |
|---|---|---|---|
| (new) | `requested` | customer | `POST /api/rides` |
| `requested` | `accepted` | the ride's driver | `POST /api/rides/{id}/accept` |
| `requested` | `declined` | the ride's driver | `POST /api/rides/{id}/decline` |
| `requested` | `cancelled` | customer | `POST /api/rides/{id}/cancel` |
| `accepted` | `en_route` | driver ("On my way") | `POST /api/rides/{id}/start` |
| `accepted` | `cancelled` | either party | `POST /api/rides/{id}/cancel` |
| `en_route` | `in_progress` | driver ("Start ride" at pickup) | `POST /api/rides/{id}/start-ride` |
| `en_route` | `cancelled` | either party | `POST /api/rides/{id}/cancel` |
| `in_progress` | `completed` | driver ("End ride") | `POST /api/rides/{id}/complete` |
| `in_progress` | `cancelled` | admin only (emergency) | `POST /api/rides/{id}/cancel` |

**Invariants** (hard rules in the service, not UI hopes):
1. **One active ride per driver** (`requested`→`in_progress`) — accept returns
   `RIDE_BUSY_DRIVER` if violated. (The #1 race: two customers swiping one driver.)
2. **One active ride per customer** — ride creation returns `RIDE_BUSY_CUSTOMER`.
3. **Only the targeted driver** may accept/decline/advance their own ride.
4. **Ratings only on `completed` rides**, once per participant.
5. **No timers** — a `requested` ride waits indefinitely. Trade-off (accepted): a driver
   who goes offline strands the customer until they cancel manually. Fine for demo.

`declined` and `cancelled` are distinct statuses — the name carries the actor, so the
history screen is honest for free.

## 3. Booking sequence (happy path)

```
DRIVER                      SERVER                            CUSTOMER
1. PATCH /drivers/online (online=true)
2. WS heartbeat: location:update every 5s ──► drivers.lat/lng
                                      3. GET /drivers/nearby
                                         → deck: verified, online, fresh loc,
                                           no active ride, ≤10 km, top 20
4. swipe RIGHT → confirm sheet: pickup + dropoff pins → POST /api/rides
                                       → ride row (status=requested)
                                       → socket ride:requested → user:{driverId}
                                       → + FCM push to driver device (dedupe client-side)
5. request card: [Accept] [Decline]
6. POST /api/rides/{id}/accept (server re-checks invariants)
                                       → status=accepted
                                       → socket + FCM: ride:accepted → customer + admin
7. driver: On my way → Start ride → End ride   (3 endpoints, socket+FCM each)
8. completed → both rate each other; cash exchanged offline; fare never recorded
```

The driver card shows **photo, name, rating, car, ETA, asking rate** — no total fare,
because the customer hasn't chosen a destination yet and (per decision 6) the app never
prices anything.

## 4. API contract

One envelope everywhere:
```json
{ "success": true,  "data": { ... } }
{ "success": false, "error": { "code": "RIDE_BUSY_DRIVER", "message": "Driver already has an active ride" } }
```

**Error codes:** `VALIDATION_ERROR` · `UNAUTHORIZED` · `FORBIDDEN` · `NOT_FOUND` ·
`RIDE_INVALID_TRANSITION` · `RIDE_BUSY_DRIVER` · `RIDE_BUSY_CUSTOMER` · `DRIVER_NOT_VERIFIED`

**Role access matrix** (middleware: `authenticate` → `authorize(role)` → controller):

| Endpoint | customer | driver | admin |
|---|---|---|---|
| `POST /api/register` · `POST /api/login` | ✓ | ✓ | ✓ |
| `POST /api/users/fcm-token` | ✓ | ✓ | ✓ |
| `GET /api/drivers/nearby` | ✓ | — | — |
| `POST /api/drivers` (vehicle) · `PATCH /api/drivers` · `PATCH /api/drivers/online` | — | ✓ | — |
| `POST /api/rides` | ✓ | — | — |
| `accept` / `decline` / `start` / `start-ride` / `complete` | — | ✓ (own ride only) | — |
| `cancel` | ✓ own | ✓ own | ✓ any |
| `rate` | ✓ own | ✓ own | — |
| `GET /api/rides/mine` · `GET /api/rides/{id}` | ✓ | ✓ | ✓ |
| `GET /api/admin/stats` · `GET /api/admin/drivers` · `GET /api/admin/rides` | — | — | ✓ |
| `POST /api/admin/drivers/{id}/verify` · `/suspend` | — | — | ✓ |

## 5. Auth

- Register/login → **JWT** (`sub`, `role`), 30-day expiry, bcrypt passwords.
- Middleware: `authenticate` (verify JWT) → `authorize(role)` (matrix above).
- **No refresh tokens** — cut for scope, said honestly.
- Socket.IO handshake accepts the same JWT on connect.

## 6. Realtime (Socket.IO) contract

**Principle: REST is the source of truth; the socket is a notification.** Every state
change is a REST call. The socket only announces. On reconnect: refetch state via REST,
re-join rooms. Socket.IO auto-reconnects; no state ever lives "in the socket".

**Rooms:** `user:{id}` (personal events) · `location:{driverId}` (customer follows their
driver) · `admin` (operator live view).

**Server → client:**
| Event | To | Payload |
|---|---|---|
| `ride:requested` | `user:{driverId}` | ride summary + customer name/rating |
| `ride:accepted` | `user:{customerId}`, `admin` | ride + driver info (car, plate, phone) |
| `ride:declined` | `user:{customerId}` | "driver passed" |
| `ride:updated` | both ride rooms + `admin` | `{rideId, status}` (en_route / in_progress / completed / cancelled) |
| `driver:location` | `location:{driverId}` | `{lat, lng}` |

**Client → server:** `location:update {lat,lng}` every 5s while online (the one WS
write — telemetry, not state).

**Freshness:** heartbeat older than 15s = treated offline. Two layers: the nearby query
filters stale rows lazily **and** a 10s server sweep flips `online=false` (belt + suspenders).

## 7. FCM push architecture (background/closed app)

- **Setup:** Firebase project → `google-services.json` in the Flutter app; Node uses the
  `firebase-admin` SDK with a service-account JSON (path in `.env`).
- **Token lifecycle:** after login the app registers its FCM token via
  `POST /api/users/fcm-token` → stored on `users.fcm_token`.
- **Dual delivery + dedupe:** on every ride event the server sends the socket event
  **and** an FCM message carrying the same `rideId`. Foreground = socket wins instantly,
  app drops the duplicate push. Background/closed = FCM rings; tapping deep-links via
  go_router to the tracking screen for that `rideId`.
- **Foreground presentation:** `flutter_local_notifications` shows a heads-up even while
  the app is open (without it, foreground FCM is invisible on Android).
- **Failure semantics:** an FCM send failure is logged and ignored — the socket still
  delivers when the app is open. Push is an enhancement, never the only path.

## 8. Geo & ETA (no fare math)

- `utils/distance.js`: one haversine function, unit-tested, used for (a) the nearby
  radius filter and (b) ETA on the card: `haversine(driver, customer) ÷ 25 km/h`.
- **Nearby query:** `online=1 AND verified=1 AND no active ride AND updated_at fresh`
  → filter ≤ 10 km → sort by distance → top 20. The client drops cards swiped-left this
  session (local only, no backend call).
- `price_per_km` is **display-only** (asking-rate hint on the card). No fare is ever
  computed, quoted, or stored.

## 9. Fare & payment model (offline)

- Negotiation happens **in person**, before pickup. The app's only involvement: the
  card's asking-rate hint.
- Payment: **cash on arrival**. No wallet, no payment endpoints, no ledger.
- `rides.fare DECIMAL NULL` — reserved column, always NULL in v1. Costless future hook.

## 10. Database (MySQL, Sequelize migrations)

```sql
users   (id, role ENUM('customer','driver','admin'), name, phone, email UNIQUE,
         password_hash, photo, rating DECIMAL(2,1), active BOOL,
         fcm_token VARCHAR NULL, timestamps)

drivers (id, user_id FK, car_model, plate, license_no,
         verified BOOL, online BOOL, price_per_km DECIMAL,     -- asking-rate hint only
         lat DECIMAL(10,7), lng DECIMAL(10,7), updated_at)

rides   (id, customer_id FK, driver_id FK,
         status ENUM('requested','accepted','declined','en_route',
                     'in_progress','completed','cancelled'),
         pickup_lat, pickup_lng, pickup_address,
         dropoff_lat, dropoff_lng, dropoff_address,
         fare DECIMAL NULL,                                    -- reserved, never set
         customer_rating TINYINT NULL, driver_rating TINYINT NULL,
         timestamps)
```

No wallet tables. No messages table (chat was cut).

## 11. Backend structure (Node/Express)

```
server/src/
  server.js             # boot: express + socket.io attach + listen :3000
  config/               # dotenv (PORT, DB, JWT_SECRET, FIREBASE_SERVICE_ACCOUNT), sequelize, firebase-admin
  models/               # Sequelize: User, Driver, Ride + associations
  migrations/ seeders/  # schema + demo data
  routes/               # thin: method + path → middleware chain → controller
  controllers/          # parse → call service → respond (envelope)
  services/             # ★ RideService (state machine + all invariants), DriverService, StatsService
  middlewares/          # authenticate, authorize, validate(zod), errorHandler
  realtime/             # socket.js: handshake auth, room joins, emit helpers
  push/                 # fcm.js: sendPush(userId, {title, body, data:{rideId}})
  utils/                # distance.js (haversine), jwt.js
```

**Every invariant from §2 lives in exactly one file (`RideService`).** Controllers never
touch ride rows directly — that's what makes the rules enforceable instead of hopeful.

## 12. Flutter structure (feature-first)

```
lib/
  main.dart · app.dart     # MaterialApp, theme (Sora + Plus Jakarta Sans), go_router
  core/                    # dio client, socket client, FCM service, constants, design tokens
  features/
    auth/                  # login/register, role redirect
    deck/                  # ★ swipe deck: GestureDetector + Transform + BOOK/PASS overlay
    booking/               # confirm sheet: pickup + dropoff pins, cash method
    tracking/              # flutter_map, live driver marker, ride status steps
    driver/                # online toggle, request card (Accept/Decline), ride control
    admin/                 # KPIs, verify drivers, live monitor (map + feed)
    rides/                 # history + rating
  shared/                  # card widgets, buttons, empty states
```

- **State:** Riverpod — `authProvider`, `socketProvider`, `deckProvider`,
  `rideProvider` (active ride, fed by REST *and* socket pushes).
- **Navigation:** go_router redirect — not logged in → auth; logged in → dashboard by
  `role`. Role routing is enforced in three layers (server middleware, router redirect,
  UI gating) so a customer can never render an admin screen.
- **Repositories** wrap Dio (`RideRepo`, `DriverRepo`) — widgets never see HTTP.

## 13. Environments & demo topology

| Stage | Topology |
|---|---|
| Dev | MySQL local (or Docker) · `node src/server.js` :3000 · emulator → `http://10.0.2.2:3000` |
| Demo | laptop + phone on same WiFi · phone → `http://<LAN-IP>:3000` · firewall allow 3000 |
| Push | FCM works on emulators **with a Play-Services image** and on real phones |
| Config | server `.env` (PORT, DB, JWT_SECRET, service account) · app `--dart-define=API_BASE_URL` |
| Seeds | 1 admin · 2–3 customers · 3–5 drivers around one map center · completed rides + ratings (so history/admin stats aren't empty) |

## 14. Testing strategy (energy on the risky 10%)

- **Backend unit:** `distance.js` (haversine) · `RideService` transitions + invariants
  (busy driver, busy customer, invalid transition, only-own-driver).
- **Backend integration** (supertest): happy path register→book→accept→complete→rate;
  plus decline, cancel, unverified-driver gate.
- **Flutter:** widget test — a fling fires `onSwipedRight`; provider tests on ride state.
- **Demo matrix:** scripted happy path + 3 failure demos (driver declines, customer
  cancels, backgrounded phone rings via FCM — the money shot). Rehearse twice.

## 15. Explicitly out of scope

Refresh tokens · wallet (dropped by decision) · in-app chat (cut) · real payments ·
fare/pricing engine · `expired` ride status · HTTPS/TLS · horizontal scaling · address
geocoding (pickup/dropoff = map pin + free-text label) · rate limiting beyond a basic
auth throttle · i18n.
