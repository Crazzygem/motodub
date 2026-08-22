// ARCHITECTURE §4 envelope: { success, data } | { success, error: { code, message } }
const STATUS = {
  VALIDATION_ERROR: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  DRIVER_NOT_VERIFIED: 400,
  RIDE_BUSY_CUSTOMER: 409, // conflict — §2 invariant 2
  RIDE_BUSY_DRIVER: 409, // conflict — §2 invariant 1
  RIDE_INVALID_TRANSITION: 409, // conflict — §2 table violated
};

export const ok = (res, data, status = 200) =>
  res.status(status).json({ success: true, data });

export const fail = (res, code, message) =>
  res.status(STATUS[code] ?? 500).json({ success: false, error: { code, message } });
