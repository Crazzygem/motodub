# DEMO.md — scripted demo

Rehearsable sequence for the final demo. **Run `npm run seed:reset` before every
rehearsal** (drops + recreates all tables, seeds PROJECT.md §5 accounts, stamps
fresh heartbeats). Server must be running (`cd server && npm run dev`, port 3000).

## 0. Environment

| Thing | Value |
|---|---|
| Server | `cd server && npm run dev` → port 3000 |
| Reset state | `npm run seed:reset` (in `server/`) |
| Emulator app | `flutter run` — default `API_BASE_URL=http://10.0.2.2:3000` |
| Phone app | `flutter run --dart-define=API_BASE_URL=http://192.168.1.88:3000` |
| LAN IP | 192.168.1.88 |

### Two devices, one backend

- Phone and emulator both talk to the same laptop backend. Same WiFi for the phone.
- Laptop firewall (firewalld is active here — `command -v firewall-cmd`):

  ```bash
  sudo firewall-cmd --add-port=3000/tcp --permanent && sudo firewall-cmd --reload
  ```

  (If a machine uses ufw instead: `sudo ufw allow 3000/tcp`. Not needed on this
  laptop — no `ufw` binary present.)
- APK build for Task 8.2: `flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.88:3000`.

### Heartbeat / staleness rule (15 s)

A driver counts as *nearby/online* only while his heartbeat is fresher than 15 s;
a server sweep flips stale drivers offline every 10 s. The driver app heartbeats
only while open — so:

- Keep driver apps **open** during the whole demo (backgrounding the *customer*
  phone is fine; backgrounding a *driver* device kills his presence).
- If screenshots look wrong (drivers missing from deck/map): re-run
  `npm run seed:reset`, which also refreshes all heartbeat timestamps.

---

## Demo accounts (PROJECT.md §5)

| Role | Email | Password | Notes |
|---|---|---|---|
| admin | admin@taxi.demo | `Admin@123` | operator dashboard |
| customer 1 | srey@taxi.demo | `Demo@123` | has completed rides in history |
| customer 2 | vithy@taxi.demo | `Demo@123` | fresh account |
| driver 1 | dara@taxi.demo | `Demo@123` | verified, asking rate $1.20/km, SUV |
| driver 2 | sophea@taxi.demo | `Demo@123` | verified, asking rate $0.90/km, sedan |
| driver 3 | vuthy@taxi.demo | `Demo@123` | **unverified** (for the admin-verify demo) |

Demo map center: Phnom Penh (11.5564, 104.9282).

---

## Path A — Happy path (the money run)

Setup: `npm run seed:reset` · customer app = phone (srey) · driver app =
emulator (dara).

1. **srey** logs in → deck shows nearby drivers (dara SUV $1.20/km, sophea
   sedan $0.90/km — both online).
2. Swipe right on **dara** → booking sheet: pickup/dropoff pins + labels,
   asking-rate pill ($1.20/km, display only — never a fare). Confirm.
3. Push to `/tracking/{rideId}`, status **requested**.
4. **dara**'s screen rings the request card (avatar, trip km, green dot).
   Tap **Accept** → ride **accepted**, stepper step 1.
5. Both phones show live tracking — dara's marker moves on the map as the
   emulator sends heartbeats (`ride:accepted` fan-out + `location:{driverId}`).
6. **dara**: **En route** → status **en_route** (step 2, amber).
7. **dara**: **Start ride** → **in_progress** (step 3).
8. **dara**: **Complete ride** → **completed** (all steps green). FCM/push:
   "Ride completed".
9. **Both** land on the rating screen → each submits stars.
10. Proof: profiles/history show updated ratings; srey's history has a new
    completed (amber) entry; admin Rides tab lists it.

## Path B — Driver declines

1. `npm run seed:reset` (or just ensure sophea is free).
2. **vithy** logs in → swipes right on **sophea** → confirms booking →
   **requested**.
3. **sophea** taps **Decline** → ride **declined**.
4. vithy sees the mapped banner *"The driver passed on your request"* and lands
   back on the deck — swipe on. History later shows **declined** in red.
   (No auto-timeout exists — an unanswered request stays `requested` until the
   driver answers or the customer cancels.)

## Path C — Customer cancels

1. srey books any available driver → **requested** (or accepted/en_route).
2. From the tracking screen tap **Cancel** (permitted from requested /
   accepted / en_route — never once in_progress).
3. Ride → **cancelled**; driver's card drops from his queue; push "Your ride
   was cancelled". History shows the ride in **grey (cancelled)**.

## Path D — Admin

Login: `admin@taxi.demo` / `Admin@123`.

1. **Dashboard** tab: 2×2 KPIs — Live rides · Online drivers · Completed today
   · Avg rating (numbers move as other paths run).
2. **Drivers** tab: vuthy row shows **Pending** chip → **Approve** → modal
   confirms → chip flips to **Verified**.
3. **Suspend dara** → modal → chip **Suspended**.
4. Proof of suspension: srey tries booking dara → server rejects with
   `FORBIDDEN` (*"You don't have permission to do that."*); dara also can't go
   online again.
5. **Restore:** unsuspend is out of scope in v1 — run `npm run seed` (or
   `seed:reset`) to flip `users.active` back, then continue.
6. **Live Map** tab: online drivers as moving markers (heartbeat-fresh);
   stop the driver app → within ~25 s he disappears (15 s staleness + 10 s
   sweep).

## Path E — FCM money shot ⏸ PENDING

Blocked on Seth's Firebase setup: add `google-services.json` to
`app/android/app/`, set `FIREBASE_SERVICE_ACCOUNT=<path>.json` in
`server/.env`, rebuild the app. Until then the server logs
*"FCM not configured — push disabled"* and sockets carry everything.

Scripted shot (once wired): dara's app **backgrounded** → srey books him →
phone **rings/notifies** on `ride:requested` → tapping it deep-links straight
to the ride request.

---

## Seth's device dry-run checklist (timeboxed)

- [ ] `npm run seed:reset` clean output, server boots
- [ ] Path A end-to-end on two devices incl. live marker movement + double rating
- [ ] Path B decline banner + deck recovery
- [ ] Path C cancel from `requested` and from `en_route`; grey history row
- [ ] Path D verify vuthy, suspend dara, blocked booking, Live Map fade-out
- [ ] Path E after Firebase wiring: backgrounded ring + deep-link
- [ ] Firewall command applied; phone on WiFi reaches :3000
