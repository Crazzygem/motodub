import bcrypt from "bcryptjs";
import { User } from "../models/user.js";
import { signToken } from "../utils/jwt.js";

// Shared with users.service (PATCH /me, avatar) so every response that
// carries a user keeps the register/login shape.
export function publicUser(user) {
  const { id, role, name, phone, email, photo, rating, active } = user;
  return { id, role, name, phone, email, photo, rating, active };
}

export async function register({ name, phone, email, password, role }) {
  const existing = await User.findOne({ where: { email } });
  if (existing) {
    const err = new Error("Email already registered");
    err.code = "VALIDATION_ERROR";
    throw err;
  }

  const password_hash = await bcrypt.hash(password, 10);
  const user = await User.create({ role, name, phone, email, password_hash });

  return { token: signToken(user), user: publicUser(user) };
}

export async function login({ email, password }) {
  const user = await User.findOne({ where: { email } });
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    const err = new Error("Invalid email or password");
    err.code = "UNAUTHORIZED";
    throw err;
  }

  return { token: signToken(user), user: publicUser(user) };
}
