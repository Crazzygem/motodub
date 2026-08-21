import { describe, it, expect } from "@jest/globals";
import request from "supertest";
import { createApp } from "../src/app.js";

describe("GET /health", () => {
  it("returns 200 with the ok envelope", async () => {
    const res = await request(createApp()).get("/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { status: "ok" } });
  });
});
