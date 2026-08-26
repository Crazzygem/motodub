// Headless demo bot CLI — thin wrapper over src/bots/bot_manager.js (the same
// implementation the server-embedded manager runs behind /api/admin/bots).
// Simulated customers + drivers speaking the real REST + Socket.IO protocol so
// the app populates with live activity (deck, admin dashboard, history, live
// map).
//
//   node scripts/bots.js            daemon: drivers drift online, ~1 ride / 90s
//   node scripts/bots.js --burst N  N rides back-to-back, then exit
//   node scripts/bots.js --once     one full ride, then exit
//
// Hygiene: bot accounts only (never touches seeded rows); SIGINT settles or
// cancels every ride it started and flips the bot drivers offline.

import { BotManager } from "../src/bots/bot_manager.js";

const arg = process.argv[2];
const burstN = arg === "--burst" ? Math.max(0, Number(process.argv[3] ?? 0)) : null;
const once = arg === "--once";
if (arg && arg !== "--burst" && !once) {
  console.log("usage: node scripts/bots.js [--burst N | --once]");
  process.exit(1);
}

const fast = once || burstN !== null;
const manager = new BotManager({ count: 2, pace: fast ? "fast" : "daemon" });

let shuttingDown = false;
async function shutdown(exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  await manager.stop();
  process.exit(exitCode);
}
process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());

try {
  await manager.start();

  if (fast) {
    const total = burstN ?? 1;
    const { completed, failed } = await manager.runRides(total);
    console.log(`[bot] target reached ${completed}/${total} completed`);
    await shutdown(failed || completed !== total ? 1 : 0);
  } else {
    // The manager's daemon ride loop drives launches; this process just waits.
    await new Promise(() => {});
  }
} catch (err) {
  console.error(`[bot] fatal: ${err.message}`);
  await shutdown(1);
}
