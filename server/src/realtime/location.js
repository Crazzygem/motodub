import { Driver } from "../models/index.js";

/**
 * Task 4.5 — location heartbeat (ARCHITECTURE §6). The one WS write:
 * `location:update {lat, lng}` every 5s while a driver is online. Telemetry,
 * not state — invalid payloads, non-drivers and drivers without a vehicle
 * profile are ignored silently; REST stays the source of truth.
 *
 * Rooms: `location:{driverId}` (driverId = the driver's USER id, matching
 * ride events) gets `driver:location {lat, lng}` for live-tracking consumers;
 * clients opt in via `join:location {driverId}`.
 */
export function registerLocationHandlers(io) {
  io.on("connection", (socket) => {
    socket.on("join:location", ({ driverId } = {}) => {
      const id = Number(driverId);
      if (!Number.isInteger(id)) return;
      socket.join(`location:${id}`);
    });

    socket.on("location:update", async (payload = {}) => {
      try {
        const user = socket.data.user ?? {};
        if (user.role !== "driver") return;

        const lat = Number(payload.lat);
        const lng = Number(payload.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

        const driver = await Driver.findOne({ where: { user_id: user.id } });
        if (!driver) return;

        // updated_at IS the heartbeat column (§10): stamped unconditionally,
        // same semantics as the online toggle in driver.service.js.
        driver.lat = lat;
        driver.lng = lng;
        driver.updated_at = new Date();
        await driver.save();

        io.to(`location:${user.id}`).emit("driver:location", { lat, lng });
      } catch (err) {
        console.error("location:update failed:", err.message);
      }
    });
  });
}
