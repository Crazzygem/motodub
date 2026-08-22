import { describe, it, expect } from "@jest/globals";
import { haversineKm, etaMinutes } from "../src/utils/distance.js";

describe("haversineKm", () => {
  it("returns 0 for the same point", () => {
    expect(haversineKm(11.5564, 104.9282, 11.5564, 104.9282)).toBe(0);
  });

  it("gives ~111 km per 1 degree of latitude", () => {
    const d = haversineKm(10, 104.9282, 11, 104.9282);
    expect(d).toBeGreaterThan(109);
    expect(d).toBeLessThan(112);
  });

  it("Phnom Penh to Siem Reap is ~225–240 km", () => {
    const d = haversineKm(11.5564, 104.9282, 13.3622, 103.8597);
    expect(d).toBeGreaterThanOrEqual(225);
    expect(d).toBeLessThanOrEqual(240);
  });

  it("is symmetric", () => {
    const ab = haversineKm(11.5564, 104.9282, 13.3622, 103.8597);
    const ba = haversineKm(13.3622, 103.8597, 11.5564, 104.9282);
    expect(ab).toBeCloseTo(ba, 9);
  });
});

describe("etaMinutes", () => {
  it("divides distance by 25 km/h and rounds up", () => {
    expect(etaMinutes(50)).toBe(2);
    expect(etaMinutes(26)).toBe(2);
    expect(etaMinutes(10)).toBe(1);
  });

  it("rounds sub-minute distances up to 1 minute", () => {
    expect(etaMinutes(0.5)).toBe(1);
  });

  it("returns 0 for zero distance", () => {
    expect(etaMinutes(0)).toBe(0);
  });
});
