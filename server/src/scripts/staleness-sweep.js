import { pathToFileURL } from "node:url";
import { Op } from "sequelize";
import { Driver } from "../models/index.js";

// ARCHITECTURE §6 freshness: a heartbeat older than 15s means the driver is
// gone even if their app crashed before toggling offline. The nearby query
// already filters stale rows lazily — this sweep is the second layer
// (belt + suspenders): flip online=false so admin stats and busy-checks agree.
export const STALE_AFTER_MS = 15_000;
export const SWEEP_INTERVAL_MS = 10_000;

/** Flip online=false for every online driver whose heartbeat went stale. */
export async function sweepStaleDrivers({ transaction } = {}) {
  const cutoff = new Date(Date.now() - STALE_AFTER_MS);
  const [count] = await Driver.update(
    { online: false },
    {
      where: { online: true, updated_at: { [Op.lt]: cutoff } },
      transaction,
    },
  );
  return count;
}

let timer = null;

/** Start the periodic sweep; safe to call once per process (server.js). */
export function startStalenessSweep(intervalMs = SWEEP_INTERVAL_MS) {
  if (timer) return;
  timer = setInterval(() => {
    sweepStaleDrivers()
      .then((flipped) => {
        if (flipped > 0) console.log(`staleness sweep: ${flipped} offline`);
      })
      .catch((err) => console.error("staleness sweep failed:", err.message));
  }, intervalMs);
}

// Standalone entry point (dbcheck.js convention):
//   node src/scripts/staleness-sweep.js
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  console.log(
    `staleness sweep: flipping drivers offline every ${SWEEP_INTERVAL_MS / 1000}s after ${STALE_AFTER_MS / 1000}s of silence`,
  );
  startStalenessSweep();
}
