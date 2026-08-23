# MotoDub

Tinder-style taxi booking — SETEC 7th-semester mobile-dev final project. One Flutter
app, three roles (customer / driver / admin), routed by login: customers swipe through
nearby driver cards and book a ride, drivers accept requests in realtime and stream
their location, admins watch KPIs and verify drivers on a live dashboard.

| Piece | Stack |
|---|---|
| App (`app/`) | Flutter stable (repo built with 3.47) · Riverpod · go_router · flutter_map + OpenStreetMap |
| Server (`server/`) | Node 22+ · Express 5 · Socket.IO · Sequelize |
| Database | MariaDB or MySQL 8 |

## Prerequisites

- **Node.js ≥ 22** (`node -v`)
- **Flutter** stable channel (`flutter doctor` clean; repo builds with 3.47 / Dart ^3.13)
- **MariaDB / MySQL** running locally — pick one:
  - **Docker container path:** an existing MySQL container named `mysql_container` with root password `1234`, host port `3306` (this is what the dev laptop uses).
  - **Native install:** any local MariaDB/MySQL server — you only need a user that can create one database.

## 1. Database (once)

```bash
# Option A — existing mysql_container (root/1234):
docker exec mysql_container mysql -uroot -p1234 \
  -e "CREATE DATABASE motodub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Option B — native MariaDB/MySQL (use your own root/user credentials):
mysql -u root -p \
  -e "CREATE DATABASE motodub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## 2. Backend

```bash
cd server
npm install
cp .env.example .env        # fill DB_USER/DB_PASS for your DB + JWT_SECRET
npm run migrate             # create tables
npm run seed                # idempotent demo data (accounts table below)
npm test                    # jest + supertest suites
npm run dev                 # nodemon → http://localhost:3000
```

`.env` values for the container path: `DB_NAME=motodub DB_USER=root DB_PASS=1234
DB_HOST=127.0.0.1 DB_PORT=3306`. Sanity check: `curl localhost:3000/health` →
`{"success":true,"data":{"status":"ok"}}` (also `npm run db:check` verifies the DB link).

## 3. Flutter app

```bash
cd app
flutter pub get

# Emulator (Android emulator maps host's localhost to 10.0.2.2 — this is the default):
flutter run                 # API_BASE_URL defaults to http://10.0.2.2:3000

# Physical phone on the same WiFi as the backend machine:
flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:3000

flutter analyze             # must be clean
flutter test                # widget/unit suites
```

Debug APK (Task 8.2 flow): `flutter build apk --debug --dart-define=API_BASE_URL=http://<LAN-IP>:3000`.

## Demo accounts

Seeded by `npm run seed` — used by tests and [DEMO.md](DEMO.md):

| Role | Email | Password | Notes |
|---|---|---|---|
| admin | admin@taxi.demo | `Admin@123` | operator dashboard |
| customer | srey@taxi.demo | `Demo@123` | has completed rides in history |
| customer | vithy@taxi.demo | `Demo@123` | fresh account |
| driver | dara@taxi.demo | `Demo@123` | verified, $1.20/km, SUV |
| driver | sophea@taxi.demo | `Demo@123` | verified, $0.90/km, sedan |
| driver | vuthy@taxi.demo | `Demo@123` | unverified (for the admin-verify demo) |

Map center: Phnom Penh (11.5564, 104.9282).

## Push notifications (FCM)

Firebase setup is a **manual step** (create project, register package `com.pu.motodub`,
drop `google-services.json` into `app/android/app/`, point
`FIREBASE_SERVICE_ACCOUNT=` at a service-account JSON — see IMPLEMENTATION.md Task 4.7).
Without it the app works fine: the server logs *"FCM not configured — push disabled"*
and Socket.IO delivers everything while apps are foregrounded.

## Docs

| File | Contents |
|---|---|
| [DEMO.md](DEMO.md) | the rehearsed demo script (start here before demoing) |
| [PLAN.md](PLAN.md) | what we build, in what order |
| [ARCHITECTURE.md](ARCHITECTURE.md) | technical contracts (API, DB, realtime) |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | the task list |
| [DESIGN.md](DESIGN.md) | design system (Amber direction) |
| [PROJECT.md](PROJECT.md) | project facts & operations |
| [AGENTS.md](AGENTS.md) | agent workflow rules |
