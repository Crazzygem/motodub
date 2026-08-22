import { fail } from "../utils/envelope.js";

// Role gate — use after authenticate. authorize("driver") allows drivers only.
export function authorize(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return fail(res, "FORBIDDEN", "Insufficient permissions");
    }
    next();
  };
}
