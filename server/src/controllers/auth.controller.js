import { ok, fail } from "../utils/envelope.js";
import * as authService from "../services/auth.service.js";

export async function register(req, res) {
  try {
    return ok(res, await authService.register(req.body), 201);
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function login(req, res) {
  try {
    return ok(res, await authService.login(req.body));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}
