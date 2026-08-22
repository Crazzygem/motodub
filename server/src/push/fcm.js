import { readFile } from "node:fs/promises";
import { User } from "../models/index.js";

// Task 4.7 / ARCHITECTURE §7: FCM covers background/closed apps; the socket
// remains the reliable channel whenever the app is open. Everything here is
// lazy and best-effort: with no FIREBASE_SERVICE_ACCOUNT in .env the module
// logs once ("FCM not configured — push disabled") and every sendPush
// resolves as a silent no-op — ride flows must never crash or spam errors.
let messaging = null;
let initialised = false;

async function getMessaging() {
  if (initialised) return messaging;
  initialised = true;

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountPath) {
    console.log("FCM not configured — push disabled");
    return null;
  }

  try {
    const { default: admin } = await import("firebase-admin");
    const serviceAccount = JSON.parse(
      await readFile(serviceAccountPath, "utf8"),
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    messaging = admin.messaging();
  } catch (err) {
    console.error(`FCM init failed — push disabled (${err.message})`);
    messaging = null;
  }
  return messaging;
}

/**
 * Fire-and-forget push to one user's registered device. Resolves without
 * throwing in every path: unknown user, no token, unconfigured SDK, send
 * failure (logged and ignored per §7 failure semantics).
 */
export async function sendPush(userId, { title, body, rideId }) {
  try {
    const user = await User.findByPk(userId, {
      attributes: ["id", "fcm_token"],
    });
    if (!user?.fcm_token) return;

    const client = await getMessaging();
    if (!client) return;

    // rideId travels in data so the app can dedupe against socket events.
    client
      .send({
        token: user.fcm_token,
        notification: { title, body },
        data: { rideId: String(rideId), userId: String(userId) },
      })
      .catch((err) =>
        console.error(`FCM send failed for user ${userId} (${err.message})`),
      );
  } catch (err) {
    console.error(`FCM push skipped for user ${userId} (${err.message})`);
  }
}
