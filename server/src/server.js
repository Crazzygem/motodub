import http from "node:http";
import { createApp } from "./app.js";
import { attach } from "./realtime/socket.js";
import { startStalenessSweep } from "./scripts/staleness-sweep.js";

const port = process.env.PORT ?? 3000;

// One HTTP server hosts Express and Socket.IO (ARCHITECTURE §6).
const server = http.createServer(createApp());
attach(server);

// §6 freshness layer two: flip stale heartbeats offline every 10s. Skippable
// for tests/tools via SWEEP_DISABLED=1.
if (process.env.SWEEP_DISABLED === "1") {
  console.log("staleness sweep disabled (SWEEP_DISABLED=1)");
} else {
  startStalenessSweep();
  console.log("staleness sweep started (10s interval)");
}

server.listen(port, () => {
  console.log(`MotoDub API listening on http://localhost:${port}`);
});
