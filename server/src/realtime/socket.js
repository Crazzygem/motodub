import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";

// Module-level handle so events.js can announce rides from anywhere in the
// service layer. null until attach() runs — tests that call RideService
// directly (no HTTP server) must get a clean no-op, never a crash.
let io = null;

/**
 * Attaches Socket.IO to the same HTTP server as Express (ARCHITECTURE §6).
 * Handshake: the same JWT as REST via socket.handshake.auth.token →
 * join room `user:{id}`; admins additionally join `admin`.
 */
export function attach(server) {
  io = new Server(server);

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error("Authentication required"));

    try {
      const payload = jwt.verify(token, env.JWT_SECRET);
      socket.data.user = { id: payload.sub, role: payload.role };
    } catch {
      return next(new Error("Invalid or expired token"));
    }
    next();
  });

  io.on("connection", (socket) => {
    const { id, role } = socket.data.user;
    socket.join(`user:${id}`);
    if (role === "admin") socket.join("admin");
  });

  return io;
}

export function getIo() {
  return io;
}
