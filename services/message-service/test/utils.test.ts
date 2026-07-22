import { describe, expect, it } from "vitest";
import { distanceSquared, isMapName, normalizeMessage, parseInteger, parseVector } from "../src/utils";

describe("map validation", () => {
  it("accepts normal Source map names", () => {
    expect(isMapName("gm_construct")).toBe(true);
    expect(isMapName("rp-city_17_v2")).toBe(true);
  });

  it("rejects traversal and punctuation", () => {
    expect(isMapName("../gm_construct")).toBe(false);
    expect(isMapName("gm construct")).toBe(false);
  });
});

describe("message normalization", () => {
  it("trims text and normalizes line endings", () => {
    expect(normalizeMessage("  hello\r\nworld  ")).toBe("hello\nworld");
  });

  it("accepts exactly 100 characters and rejects 101", () => {
    expect(normalizeMessage("x".repeat(100))).toBe("x".repeat(100));
    expect(normalizeMessage("x".repeat(101))).toBeNull();
  });

  it("counts UTF-8 text as characters rather than bytes", () => {
    expect(normalizeMessage("🙂".repeat(100))).toBe("🙂".repeat(100));
    expect(normalizeMessage("🙂".repeat(101))).toBeNull();
  });

  it("rejects empty messages", () => {
    expect(normalizeMessage(" \n ")).toBeNull();
  });
});

describe("vector validation", () => {
  it("normalizes surface normals", () => {
    expect(parseVector({ x: 0, y: 0, z: 1.2 }, true)).toEqual({ x: 0, y: 0, z: 1 });
  });

  it("rejects invalid coordinates", () => {
    expect(parseVector({ x: 50000, y: 0, z: 0 })).toBeNull();
    expect(parseVector({ x: "wat", y: 0, z: 0 })).toBeNull();
  });
});

describe("pagination helpers", () => {
  it("clamps integers", () => {
    expect(parseInteger("999", 10, 1, 250)).toBe(250);
    expect(parseInteger(null, 10, 1, 250)).toBe(10);
  });

  it("computes squared distance", () => {
    expect(distanceSquared({ x: 0, y: 0, z: 0 }, { x: 3, y: 4, z: 0 })).toBe(25);
  });
});
