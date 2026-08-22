import { env } from "./env.js";

// Consumed by sequelize-cli (see .sequelizerc). The app itself uses db.js.
// Jest sets NODE_ENV=test, so the ride-flow suite's `DB_NAME=motodub_test
// npm run migrate` resolves through the `test` stanza below.
const settings = {
  username: env.DB_USER,
  password: env.DB_PASS,
  database: env.DB_NAME,
  host: env.DB_HOST,
  port: env.DB_PORT,
  dialect: "mysql",
};

export default {
  development: settings,
  test: settings,
};
