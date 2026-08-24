import bcrypt from "bcryptjs";
import { User } from "../models/user.js";
import { publicUser } from "./auth.service.js";

function businessError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

/**
 * Task 4.7 — POST /api/users/fcm-token. Any authenticated role may register
 * its own FCM device token (ARCHITECTURE §7 token lifecycle).
 */
export async function saveFcmToken(userId, token) {
  const [count] = await User.update(
    { fcm_token: token },
    { where: { id: userId } },
  );
  if (count === 0) {
    throw businessError("NOT_FOUND", "User not found");
  }
  return { saved: true };
}

/**
 * PATCH /api/users/me — own-row edit. Only name/phone ever reach this point
 * (the route schema strips everything else), so email stays immutable.
 */
export async function updateProfile(userId, fields) {
  const user = await User.findByPk(userId);
  if (!user) {
    throw businessError("NOT_FOUND", "User not found");
  }
  await user.update(fields);
  return publicUser(user);
}

/** POST /api/users/me/avatar — multer already wrote the file; record its URL. */
export async function setAvatar(userId, filename) {
  const user = await User.findByPk(userId);
  if (!user) {
    throw businessError("NOT_FOUND", "User not found");
  }
  await user.update({ photo: `/uploads/${filename}` });
  return publicUser(user);
}

/**
 * POST /api/users/me/password — verify the current password, then re-hash.
 * Token stays valid; the client simply logs in again with the new secret.
 */
export async function changePassword(userId, currentPassword, newPassword) {
  const user = await User.findByPk(userId);
  if (!user || !(await bcrypt.compare(currentPassword, user.password_hash))) {
    throw businessError("UNAUTHORIZED", "Current password is incorrect");
  }
  const password_hash = await bcrypt.hash(newPassword, 10);
  await user.update({ password_hash });
  return { updated: true };
}
