import { sequelize } from "../config/db.js";

try {
  await sequelize.authenticate();
  console.log("connected");
  process.exit(0);
} catch (err) {
  console.error("db check failed:", err.message);
  process.exit(1);
}
