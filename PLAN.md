# Tinder-Style Taxi Booking — Final Project Plan (v3)

> Goal: An Android mobile app (Flutter) for booking taxis with a Tinder-style swipe
> deck, backed by a custom REST + WebSocket API. Three roles: **customer**
> (passenger), **user** (driver), **admin** (operator) — one app, role-routed after login.
> Full technical contract: see **ARCHITECTURE.md** (same folder).

**Decisions (locked with Seth, 2026-08-20):**
| # | Decision | Chosen |
|---|----------|--------|
| 1 | Roles | Customer = passenger, User = driver, Admin = operator |
| 2 | Backend | Node.js + Express + Socket.IO + MySQL (Sequelize), JWT, one process |
| 3 | Swipe | One-sided: customer swipes driver cards, right = book; driver accepts/declines with buttons |
| 4 | Matching | Direct request to the ONE swiped driver (true Tinder model) |
| 5 | Request lifetime | No expiry timer; customer can cancel anytime |
| 6 | Notifications | Socket.IO (foreground) + FCM push (background/closed), deduped |
| 7 | Fare | Negotiated offline in person — never stored; `fare` column reserved (NULL) |
| 8 | Payment | Cash on arrival — wallet dropped |
| 9 | Card price hint | Driver card shows asking rate (`price_per_km`) as negotiation starting point |
| 10 | Apps | One Flutter app (teacher requirement), role-routed after login |
| 11 | Map | `flutter_map` + OpenStreetMap (no API key) |
| 12 | Teacher rule | No backend constraint — any backend allowed |

**Locked dependencies:** Flutter `dio` · `socket_io_client` · `flutter_map` · `riverpod` ·
`go_router` · `flutter_local_notifications`. Backend `express` · `socket.io` · `mysql2` +
`sequelize` · `jsonwebtoken` · `bcrypt` · `zod` · `firebase-admin`.

---

## 1. Architecture (summary — full contract in ARCHITECTURE.md)

- One Node process serves REST **and** Socket.IO on the same port (:3000).
- **REST is the source of truth**; the socket only announces changes; FCM covers
  backgrounded phones. Reconnect = refetch via REST, rejoin rooms.
- All ride rules live in one `RideService` (state machine + invariants: one active ride
  per driver/customer, only-own-driver actions, ratings only on completed).
- No fare math anywhere: cards show ETA (haversine) + asking-rate hint; fare is
  negotiated in person and never recorded.

## 2. MySQL schema (3 tables)

```sql
users   (id, role ENUM('customer','driver','admin'), name, phone, email UNIQUE,
         password_hash, photo, rating, active, fcm_token NULL, timestamps)

drivers (id, user_id FK, car_model, plate, license_no, verified, online,
         price_per_km,                       -- asking-rate hint only
         lat, lng, updated_at)               -- location = WS heartbeat

rides   (id, customer_id FK, driver_id FK,
         status ENUM('requested','accepted','declined','en_route',
                     'in_progress','completed','cancelled'),
         pickup_lat/lng/address, dropoff_lat/lng/address,
         fare NULL,                          -- reserved, never set
         customer_rating NULL, driver_rating NULL, timestamps)
```

## 3. API endpoints (REST)

- Auth: `POST /api/register` · `POST /api/login` → JWT · `POST /api/users/fcm-token`
- Drivers: `GET /api/drivers/nearby` · `POST /api/drivers` · `PATCH /api/drivers` · `PATCH /api/drivers/online`
- Rides: `POST /api/rides` · `POST /api/rides/{id}/accept|decline|start|start-ride|complete|cancel|rate` · `GET /api/rides/mine` · `GET /api/rides/{id}`
- Admin: `GET /api/admin/stats|drivers|rides` · `POST /api/admin/drivers/{id}/verify|suspend`

## 4. The flow

```
CUSTOMER                     BACKEND                        DRIVER
deck ← GET /drivers/nearby   (verified, online, fresh loc, no active ride, ≤10km, top 20)
swipe RIGHT → confirm sheet (pickup + dropoff) → POST /api/rides → status=requested
                              │ socket ride:requested + FCM push → user:{driverId}
                              ▼
                      request card [Accept] [Decline]
◄── socket+FCM ride:accepted ── driver taps Accept
tracking: en_route → in_progress → completed (each = 1 endpoint, socket+FCM)
completed → both rate; cash exchanged offline; fare never recorded
```

- Swipe LEFT is purely local (pop card). Driver card shows: photo, name, rating, car,
  ETA, asking rate — no total fare (no destination chosen yet, and the app never prices).

## 5. Screens by role

**Customer:** login/register → home deck → confirm sheet (pickup/dropoff pins, cash) →
live tracking → rate → history.
**Driver:** login/vehicle setup (needs admin verify) → online/offline toggle → request
card with Accept/Decline → On my way → Start ride → End ride → ratings received.
**Admin:** KPIs (live rides, online drivers) · driver verification (approve/reject/
suspend) · live ride monitor (WS + map) · customer list.

**Swipe deck component** (showpiece): `GestureDetector` + `onPanEnd` velocity check →
`Transform.rotate+translate` top card, fade BOOK / PASS overlay, pop to next card.

## 6. Build phases (each = a demo checkpoint)

| Phase | Build | Verify |
|---|---|---|
| 0 | Flutter app + Node/Express + MySQL up; **create Firebase project** (FCM needs it early) | `flutter run` boots; server on :3000 with DB; login screen appears |
| 1 | Auth + JWT + role routing; seed admin | customer/driver/admin land on their own dashboards |
| 2 | Data layer: Sequelize models/migrations/seeders + Flutter models + Dio client | register → login → GET user works end-to-end |
| 3 | **Customer swipe deck** hitting `/drivers/nearby` (cards: rating, car, ETA, asking rate) | seeded driver card shows; right-swipe creates a `requested` ride (check MySQL) |
| 4 | Driver request card + Accept/Decline; **FCM dual delivery + dedupe**; fcm-token registration | Accept flips ride to `accepted` live on both apps; backgrounded phone rings + deep-links |
| 5 | Trip tracking: WS location stream + en_route → in_progress → completed | both clients update live on each transition |
| 6 | Admin dashboard: verify driver, live ride monitor, stats | approve a driver; completed rides appear in stats |
| 7 | Ratings, history, empty states, polish (Sora/Jakarta design) | full happy path: swipe → book → accept → ride → rate |
| 8 | Demo prep: two accounts, two devices, backend reachable, push rehearsal, screenshots/video | scripted demo runs top to bottom, including the FCM money shot |

## 7. Demo / networking (classic pitfalls)

- **Emulator → host:** `http://10.0.2.2:3000`; physical phone → LAN IP + firewall allow 3000.
- **FCM:** emulator must be a Play-Services image; phone must be logged into Google. The
  Firebase project + `google-services.json` exist from Phase 0, not demo day.
- **Two devices mandatory** — the app's whole point is two sides talking (emulator +
  real phone, or two emulators).
- Backend on localhost for the demo; lift to a VPS (`node server.js` + PM2) only if the
  course wants a persistent deployment.

## 8. Risks & scope cuts (if the deadline closes in)

- Cut list, in order: admin live-map → plain list · drop charts/analytics · static
  pickup→dropoff line instead of live map · FCM last (it's demo-day insurance).
- Real-time WS auth — JWT in the Socket.IO handshake; keep rooms simple (`user:{id}`).
- Biggest single risk: two-device networking + push on demo day — rehearse Phase 8 twice.

## 9. Version history

- v1: initial plan (Laravel/Reverb variant) · v2: switched backend to Node/Express +
  Socket.IO · v3: architecture completed — direct matching, no expiry, FCM added, fare
  negotiated offline (unrecorded), wallet dropped. See ARCHITECTURE.md for full detail.
