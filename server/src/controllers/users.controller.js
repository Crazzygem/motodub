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

export async function updateMe(req, res) {
  try {
    return ok(res, await usersService.updateProfile(req.user.id, req.body));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function uploadAvatar(req, res) {
  try {
    return ok(res, await usersService.setAvatar(req.user.id, req.file.filename));
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}

export async function changeMyPassword(req, res) {
  try {
    return ok(
      res,
      await usersService.changePassword(
        req.user.id,
        req.body.current_password,
        req.body.new_password,
      ),
    );
  } catch (err) {
    if (!err.code) throw err;
    return fail(res, err.code, err.message);
  }
}
