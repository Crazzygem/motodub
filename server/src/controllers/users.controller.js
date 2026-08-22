import { ok, fail } from "../utils/envelope.js";
import * as usersService from "../services/users.service.js";

export async function saveFcmToken(req, res) {
  try {
    return ok(res, await usersService.saveFcmToken(req.user.id, req.body.token));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}
