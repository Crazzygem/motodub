import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { fail } from "../utils/envelope.js";

// Verifies Authorization: Bearer <jwt> and attaches req.user = { id, role }.
export function authenticate(req, res, next) {
  const header = req.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;

  if (!token) {
    return fail(res, "UNAUTHORIZED", "Authentication required");
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET);
    req.user = { id: payload.sub, role: payload.role };
    next();
  } catch {
    return fail(res, "UNAUTHORIZED", "Invalid or expired token");
  }
}
