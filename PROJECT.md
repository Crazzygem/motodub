# PROJECT.md — MotoDub project facts & operations

> Project-specific facts for agents and humans. **No workflow rules here** — how to
> work lives in AGENTS.md. Docs index:
> **PLAN.md** (what we build, in order) · **ARCHITECTURE.md** (contracts) ·
> **IMPLEMENTATION.md** (task list) · **AGENTS.md** (workflow + rules)

## 1. Identity

- Semester final project (SETEC, 7th-semester mobile-dev). Teacher requires a
  **Flutter/Dart** frontend; the backend choice is free (locked: Node.js).
- Product: **MotoDub** — Tinder-style taxi booking. Three roles in **one Flutter app**:
  **customer** (passenger, swipes driver cards) · **driver** (accepts rides) ·
  **admin** (operator). Role routing after login.
- Repo: single git repo at `final-project/` — `app/` (Flutter) + `server/` (Node) + docs.
- **Binding identifiers:** applicationId **`com.pu.motodub`** (flutter project name
  `motodub`, org `com.pu`, display name "MotoDub"). Never change — Firebase depends on it.

## 2. Locked product decisions (do not "improve")

| Decision | Locked value |
|---|---|
| Matching | Direct request to the swiped driver only (no broadcast) |
| Request lifetime | No expiry timer — customer can cancel anytime |
| Notifications | Socket.IO (foreground) + FCM (background/closed), deduped by `rideId` |
| Fare | Negotiated offline, **never stored** — `fare` column stays NULL, **no fare math anywhere** |
| Card price hint | Asking rate (`price_per_km`) on the card — display-only |
| Payment | Cash on arrival — **no wallet, no chat, no `expired` status** |
| Map | `flutter_map` + OpenStreetMap (no API key) |

Full contract detail: ARCHITECTURE.md decision log + §15 out-of-scope whitelist.

## 3. Verified environment (Seth's laptop, checked 2026-08-21)

| Tool | Version / status |
|---|---|
| Node.js | v22.23.2 (npm 12.0.2) ✅ |
| Database | **MySQL 8.0.46 in existing Docker container `mysql_container`** (root/`1234`, host port 3306) — the `motodub` database is created inside it by Task 0.3. System MariaDB service is inactive — do **not** touch it or the container's other databases |
| Flutter SDK | **NOT installed — Task 0.0 installs it** (standalone tarball to `~/development/flutter` or Android Studio plugin; then `flutter doctor --android-licenses`, `flutter config --android-sdk /home/seth/Android/Sdk`) |
| Android | SDK at `/home/seth/Android/Sdk` ✅ · `ANDROID_HOME` unset (set after Flutter install) · no AVDs yet (create in Android Studio, or use Waydroid as demo device #1 — no Play Services, FCM won't ring there) |
| Java | OpenJDK 25 ✅ — if Gradle rejects it at first build, install Temurin 21 |
| git | 2.55.0 ✅ |

## 4. Commands

```bash
# Server (from final-project/)
cd server && npm install
npm run dev          # nodemon, listens :3000 (REST + Socket.IO same port)
npm test             # jest + supertest
npm run migrate      # sequelize-cli migrations
npm run seed         # idempotent demo data (accounts below)
npm run seed:reset   # drop + recreate + seed
npm run db:check     # verify DB connection

# App (from final-project/)
cd app && flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # emulator → host
flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:3000   # physical phone
flutter test
flutter analyze
```

Database (existing MySQL 8.0 container) — create once:
`docker exec mysql_container mysql -uroot -p1234 -e "CREATE DATABASE motodub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"`
Connect string for `.env`: `DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=root DB_PASS=1234 DB_NAME=motodub`.
The container is shared — never drop containers, never touch databases other than `motodub`.

## 5. Demo accounts (seeded — used by tests and DEMO.md)

| Role | Email | Password | Notes |
|---|---|---|---|
| admin | admin@taxi.demo | `Admin@123` | operator dashboard |
| customer 1 | srey@taxi.demo | `Demo@123` | has completed rides in history |
| customer 2 | vithy@taxi.demo | `Demo@123` | fresh account |
| driver 1 | dara@taxi.demo | `Demo@123` | verified, asking rate $1.20/km, SUV |
| driver 2 | sophea@taxi.demo | `Demo@123` | verified, asking rate $0.90/km, sedan |
| driver 3 | vuthy@taxi.demo | `Demo@123` | **unverified** (for the admin-verify demo) |

**Demo map center:** Phnom Penh (11.5564, 104.9282).

## 6. Design tokens

Canonical design spec: **DESIGN.md** (locked 2026-08-21 — Amber direction: palette,
type scale, components, motion). One-liner: Sora headings + Plus Jakarta Sans body,
amber `#F59E0B` on `#FAFAF9` with ink `#111827`; admin destructive actions via modal
dialogs. No default fonts, no empty screens.

## 7. Secrets policy

`.env` and `google-services.json` are gitignored — never commit them. Commit
`.env.example` with placeholder values instead. FCM service-account JSON path lives in
`server/.env` as `FIREBASE_SERVICE_ACCOUNT`.

## 8. Out-of-scope whitelist (ARCHITECTURE §15)

Refresh tokens · wallet · in-app chat · real payments · fare/pricing engine ·
`expired` ride status · HTTPS/TLS · horizontal scaling · address geocoding (pins +
free-text labels only) · rate limiting beyond a basic auth throttle · i18n.