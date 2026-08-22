import { fail } from "../utils/envelope.js";

// Zod body validation middleware. On success replaces req.body with the
// parsed (defaults applied) value; on failure answers the §4 envelope
// directly (the global error handler arrives in Task 1.3).
export function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return fail(res, "VALIDATION_ERROR", result.error.issues[0]?.message ?? "Invalid input");
    }
    req.body = result.data;
    next();
  };
}
