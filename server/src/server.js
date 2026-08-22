import http from "node:http";
import { createApp } from "./app.js";
import { attach } from "./realtime/socket.js";

const port = process.env.PORT ?? 3000;

// One HTTP server hosts Express and Socket.IO (ARCHITECTURE §6).
const server = http.createServer(createApp());
attach(server);

server.listen(port, () => {
  console.log(`MotoDub API listening on http://localhost:${port}`);
});
