import "dotenv/config";

export const env = {
  PORT: process.env.PORT ?? 3000,
  DB_NAME: process.env.DB_NAME ?? "motodub",
  DB_USER: process.env.DB_USER ?? "root",
  DB_PASS: process.env.DB_PASS ?? "",
  DB_HOST: process.env.DB_HOST ?? "127.0.0.1",
  DB_PORT: process.env.DB_PORT ? Number(process.env.DB_PORT) : 3306,
  JWT_SECRET: process.env.JWT_SECRET ?? "dev-only-secret-change-me",
};
