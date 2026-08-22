import { User } from "../models/user.js";

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
