import type { Vector3 } from "./types";

export const MAP_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
export const STEAM_ID_PATTERN = /^7656119\d{10}$/;
export const TICKET_PATTERN = /^[A-Za-z0-9_-]{32,128}$/;
export const MAX_MESSAGE_CHARACTERS = 100;
export const MAX_MESSAGE_BYTES = 400;
export const MAX_COORDINATE = 32768;

export function json(data: unknown, status = 200, extraHeaders: HeadersInit = {}): Response {
  const headers = new Headers(extraHeaders);
  headers.set("content-type", "application/json; charset=utf-8");
  headers.set("cache-control", "no-store");
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-headers", "authorization, content-type, x-admin-token, x-server-token");
  headers.set("access-control-allow-methods", "GET, POST, DELETE, OPTIONS");
  return new Response(JSON.stringify(data), { status, headers });
}

export function apiError(status: number, code: string, message: string): Response {
  return json({ ok: false, error: code, message }, status);
}

export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function randomToken(byteLength = 32): string {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function normalizeMessage(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value
    .replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .trim();
  if (!normalized || normalized.split("\n").length > 4) return null;
  if (Array.from(normalized).length > MAX_MESSAGE_CHARACTERS) return null;
  if (new TextEncoder().encode(normalized).length > MAX_MESSAGE_BYTES) return null;
  return normalized;
}

export function parseVector(value: unknown, requireNormal = false): Vector3 | null {
  if (!value || typeof value !== "object") return null;
  const record = value as Record<string, unknown>;
  const x = Number(record.x);
  const y = Number(record.y);
  const z = Number(record.z);
  if (![x, y, z].every(Number.isFinite)) return null;
  if ([x, y, z].some((n) => Math.abs(n) > MAX_COORDINATE)) return null;

  if (!requireNormal) return { x, y, z };
  const length = Math.sqrt(x * x + y * y + z * z);
  if (length < 0.5 || length > 1.5) return null;
  return { x: x / length, y: y / length, z: z / length };
}

export function parseInteger(value: string | null, fallback: number, minimum: number, maximum: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(minimum, Math.min(maximum, parsed));
}

export function isMapName(value: string): boolean {
  return MAP_PATTERN.test(value);
}

export function distanceSquared(a: Vector3, b: Vector3): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  const dz = a.z - b.z;
  return dx * dx + dy * dy + dz * dz;
}

export function htmlEscape(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character] ?? character);
}
