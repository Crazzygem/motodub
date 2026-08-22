import { env } from "./env.js";

// Consumed by sequelize-cli (see .sequelizerc). The app itself uses db.js.
export default {
  development: {
    username: env.DB_USER,
    password: env.DB_PASS,
    database: env.DB_NAME,
    host: env.DB_HOST,
    port: env.DB_PORT,
    dialect: "mysql",
  },
};
