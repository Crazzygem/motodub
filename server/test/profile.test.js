import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import request from "supertest";
import fs from "node:fs";
import path from "node:path";
import { User } from "../src/models/index.js";
import { sequelize } from "../src/config/db.js";
import { createApp } from "../src/app.js";

const app = createApp();
const uploadsDir = path.resolve(process.cwd(), "uploads");

// 1x1 PNG, in memory — the smallest real image bytes we can attach.
const TINY_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

let token;
let fixtureEmail;
const uploadedFiles = [];

function authed(req) {
  return req.set("Authorization", `Bearer ${token}`);
}

beforeAll(async () => {
  await sequelize.authenticate();

  fixtureEmail = `${Date.now()}-profile@test.demo`;
  const reg = await request(app).post("/api/register").send({
    name: "Profile Pat",
    phone: "012346679",
    email: fixtureEmail,
    password: "Password1",
  });
  expect(reg.status).toBe(201);
  token = reg.body.data.token;
});

afterAll(async () => {
  for (const name of uploadedFiles) {
    fs.rmSync(path.join(uploadsDir, name), { force: true });
  }
  if (fixtureEmail) {
    await User.destroy({ where: { email: fixtureEmail } });
  }
  await sequelize.close();
});

describe("PATCH /api/users/me", () => {
  it("rejects an unauthenticated caller with UNAUTHORIZED", async () => {
    const res = await request(app)
      .patch("/api/users/me")
      .send({ name: "No Auth" });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("updates own name and phone and persists them", async () => {
    const res = await authed(request(app).patch("/api/users/me")).send({
      name: "Pat Renamed",
      phone: "+855 999 888",
    });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    // Same publicUser shape as register/login responses.
    expect(res.body.data).toMatchObject({
      role: "customer",
      name: "Pat Renamed",
      phone: "+855 999 888",
      rating: expect.anything(),
      active: true,
    });

    const row = await User.findOne({ where: { email: fixtureEmail } });
    expect(row.name).toBe("Pat Renamed");
    expect(row.phone).toBe("+855 999 888");
  });

  it("never touches email even when the payload includes it", async () => {
    const res = await authed(request(app).patch("/api/users/me")).send({
      name: "Pat Still Here",
      email: "hijacked@evil.demo",
    });

    expect(res.status).toBe(200);
    const row = await User.findOne({ where: { email: fixtureEmail } });
    expect(row.email).toBe(fixtureEmail);
    expect(res.body.data.email).toBe(fixtureEmail);
  });

  it("rejects a malformed phone with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).patch("/api/users/me")).send({
      phone: "abc!@#",
    });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects an empty update with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).patch("/api/users/me")).send({});

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});

describe("POST /api/users/me/avatar", () => {
  it("rejects an unauthenticated caller with UNAUTHORIZED", async () => {
    const res = await request(app)
      .post("/api/users/me/avatar")
      .attach("avatar", TINY_PNG, "me.png");

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("stores a jpeg/png/webp upload under /uploads and saves the URL on photo", async () => {
    const res = await authed(request(app).post("/api/users/me/avatar"))
      .attach("avatar", TINY_PNG, { filename: "me.png", contentType: "image/png" });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const photo = res.body.data.photo;
    expect(photo).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);

    const onDisk = path.join(uploadsDir, path.basename(photo));
    expect(fs.existsSync(onDisk)).toBe(true);
    uploadedFiles.push(path.basename(photo));
  });

  it("rejects a non-image upload with VALIDATION_ERROR", async () => {
    const before = fs.existsSync(uploadsDir)
      ? fs.readdirSync(uploadsDir).length
      : 0;

    const res = await authed(request(app).post("/api/users/me/avatar"))
      .attach("avatar", Buffer.from("not an image"), { filename: "note.txt", contentType: "text/plain" });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");

    // Nothing may have been written for a rejected upload.
    const after = fs.existsSync(uploadsDir)
      ? fs.readdirSync(uploadsDir).length
      : 0;
    expect(after).toBe(before);
  });

  it("rejects an oversized upload with VALIDATION_ERROR", async () => {
    const bigPng = Buffer.concat([TINY_PNG, Buffer.alloc(5 * 1024 * 1024)]);
    const before = fs.existsSync(uploadsDir)
      ? fs.readdirSync(uploadsDir).length
      : 0;

    const res = await authed(request(app).post("/api/users/me/avatar"))
      .attach("avatar", bigPng, { filename: "big.png", contentType: "image/png" });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");

    const after = fs.existsSync(uploadsDir)
      ? fs.readdirSync(uploadsDir).length
      : 0;
    expect(after).toBe(before);
  });
});

describe("POST /api/users/me/password", () => {
  const newPassword = "NewPass456";

  it("rejects a wrong current password with UNAUTHORIZED", async () => {
    const res = await authed(request(app).post("/api/users/me/password")).send({
      current_password: "WrongPass0",
      new_password: newPassword,
    });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe("UNAUTHORIZED");
  });

  it("changes the password: old stops working, new logs in", async () => {
    const res = await authed(request(app).post("/api/users/me/password")).send({
      current_password: "Password1",
      new_password: newPassword,
    });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const oldLogin = await request(app).post("/api/login").send({
      email: fixtureEmail,
      password: "Password1",
    });
    expect(oldLogin.status).toBe(401);
    expect(oldLogin.body.error.code).toBe("UNAUTHORIZED");

    const newLogin = await request(app).post("/api/login").send({
      email: fixtureEmail,
      password: newPassword,
    });
    expect(newLogin.status).toBe(200);
    expect(newLogin.body.data.token).toBeTruthy();
  });

  it("rejects a short new password with VALIDATION_ERROR", async () => {
    const res = await authed(request(app).post("/api/users/me/password")).send({
      current_password: "NewPass456",
      new_password: "short",
    });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});
