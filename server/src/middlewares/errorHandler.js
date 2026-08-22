import { fail } from "../utils/envelope.js";

// Last middleware: every thrown error leaves as the §4 envelope.
// Errors carrying a .code keep their message + mapped status; anything
// else is logged and returned as 500 INTERNAL (no internals leaked).
export function errorHandler(err, _req, res, _next) {
  if (!err.code) {
    console.error("[unhandled]", err);
    return fail(res, "INTERNAL", "Internal server error");
  }
  return fail(res, err.code, err.message);
}
