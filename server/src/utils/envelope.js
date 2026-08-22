// ARCHITECTURE §4 envelope: { success, data } | { success, error: { code, message } }
const STATUS = {
  VALIDATION_ERROR: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
};

export const ok = (res, data, status = 200) =>
  res.status(status).json({ success: true, data });

export const fail = (res, code, message) =>
  res.status(STATUS[code] ?? 500).json({ success: false, error: { code, message } });
