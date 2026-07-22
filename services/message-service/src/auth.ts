import type { Env, Session } from "./types";
import { apiError, htmlEscape, json, nowSeconds, randomToken, sha256Hex, STEAM_ID_PATTERN, TICKET_PATTERN } from "./utils";

const STEAM_OPENID_ENDPOINT = "https://steamcommunity.com/openid/login";
const TICKET_TTL = 10 * 60;
const SESSION_TTL = 30 * 24 * 60 * 60;

function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

export async function requireSession(request: Request, env: Env): Promise<Session | Response> {
  const token = bearerToken(request);
  if (!token) return apiError(401, "authentication_required", "Sign in with Steam before using this endpoint.");
  const tokenHash = await sha256Hex(token);
  const now = nowSeconds();
  const row = await env.DB.prepare(
    "SELECT steamid64 FROM sessions WHERE token_hash = ?1 AND expires_at > ?2"
  ).bind(tokenHash, now).first<{ steamid64: string }>();
  if (!row) return apiError(401, "invalid_session", "The login session is invalid or expired.");
  await env.DB.prepare("UPDATE sessions SET last_seen_at = ?1 WHERE token_hash = ?2")
    .bind(now, tokenHash).run();
  return { steamid64: row.steamid64, tokenHash };
}

export async function startSteamLogin(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const ticket = url.searchParams.get("ticket") ?? "";
  if (!TICKET_PATTERN.test(ticket)) return apiError(400, "invalid_ticket", "The login ticket is malformed.");

  const now = nowSeconds();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM auth_tickets WHERE created_at < ?1").bind(now - TICKET_TTL),
    env.DB.prepare("INSERT OR IGNORE INTO auth_tickets (ticket, created_at) VALUES (?1, ?2)").bind(ticket, now),
  ]);

  const callback = new URL("/v1/auth/callback", url.origin);
  callback.searchParams.set("ticket", ticket);

  const openid = new URL(STEAM_OPENID_ENDPOINT);
  openid.searchParams.set("openid.ns", "http://specs.openid.net/auth/2.0");
  openid.searchParams.set("openid.mode", "checkid_setup");
  openid.searchParams.set("openid.return_to", callback.toString());
  openid.searchParams.set("openid.realm", url.origin);
  openid.searchParams.set("openid.identity", "http://specs.openid.net/auth/2.0/identifier_select");
  openid.searchParams.set("openid.claimed_id", "http://specs.openid.net/auth/2.0/identifier_select");
  return Response.redirect(openid.toString(), 302);
}

export async function finishSteamCallback(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const ticket = url.searchParams.get("ticket") ?? "";
  if (!TICKET_PATTERN.test(ticket)) return apiError(400, "invalid_ticket", "The login ticket is malformed.");

  const ticketRow = await env.DB.prepare(
    "SELECT created_at FROM auth_tickets WHERE ticket = ?1"
  ).bind(ticket).first<{ created_at: number }>();
  if (!ticketRow || ticketRow.created_at < nowSeconds() - TICKET_TTL) {
    return apiError(410, "expired_ticket", "The login ticket expired. Return to Garry's Mod and try again.");
  }

  const returnTo = new URL("/v1/auth/callback", url.origin);
  returnTo.searchParams.set("ticket", ticket);
  if (url.searchParams.get("openid.return_to") !== returnTo.toString()) {
    return apiError(400, "return_to_mismatch", "Steam returned an unexpected callback target.");
  }
  if (url.searchParams.get("openid.op_endpoint") !== STEAM_OPENID_ENDPOINT) {
    return apiError(400, "provider_mismatch", "The OpenID provider is invalid.");
  }

  const verification = new URLSearchParams();
  url.searchParams.forEach((value, key) => {
    if (key.startsWith("openid.")) verification.set(key, value);
  });
  verification.set("openid.mode", "check_authentication");

  const steamResponse = await fetch(STEAM_OPENID_ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: verification.toString(),
  });
  const verificationText = await steamResponse.text();
  if (!steamResponse.ok || !/(?:^|\n)is_valid:true(?:\n|$)/.test(verificationText)) {
    return apiError(401, "steam_verification_failed", "Steam could not verify this login.");
  }

  const claimedId = url.searchParams.get("openid.claimed_id") ?? "";
  const steamId = claimedId.match(/^https?:\/\/steamcommunity\.com\/openid\/id\/(7656119\d{10})\/?$/)?.[1];
  if (!steamId || !STEAM_ID_PATTERN.test(steamId)) {
    return apiError(400, "invalid_steamid", "Steam returned an invalid account identifier.");
  }

  const now = nowSeconds();
  await env.DB.prepare(
    "UPDATE auth_tickets SET steamid64 = ?1, completed_at = ?2 WHERE ticket = ?3"
  ).bind(steamId, now, ticket).run();

  const safeSteamId = htmlEscape(steamId);
  return new Response(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Found Footage login</title><style>body{background:#050505;color:#d8d8d8;font:18px monospace;display:grid;place-items:center;min-height:100vh;margin:0}.box{max-width:42rem;padding:2rem;border:1px solid #444;background:#111}h1{font-size:1.25rem;color:#fff}</style></head><body><div class="box"><h1>IDENTITY RECOVERED</h1><p>Steam account ${safeSteamId} is linked.</p><p>Return to Garry's Mod. This window can be closed.</p></div></body></html>`, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'",
      "x-frame-options": "DENY",
    },
  });
}

export async function finishSteamLogin(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const ticket = url.searchParams.get("ticket") ?? "";
  if (!TICKET_PATTERN.test(ticket)) return apiError(400, "invalid_ticket", "The login ticket is malformed.");

  const now = nowSeconds();
  const row = await env.DB.prepare(
    "SELECT steamid64, created_at FROM auth_tickets WHERE ticket = ?1"
  ).bind(ticket).first<{ steamid64: string | null; created_at: number }>();
  if (!row || row.created_at < now - TICKET_TTL) {
    return apiError(410, "expired_ticket", "The login ticket expired.");
  }
  if (!row.steamid64) return json({ ok: true, status: "pending" }, 202);

  const token = randomToken(32);
  const tokenHash = await sha256Hex(token);
  await env.DB.batch([
    env.DB.prepare(
      "INSERT INTO sessions (token_hash, steamid64, created_at, expires_at, last_seen_at) VALUES (?1, ?2, ?3, ?4, ?3)"
    ).bind(tokenHash, row.steamid64, now, now + SESSION_TTL),
    env.DB.prepare("DELETE FROM auth_tickets WHERE ticket = ?1").bind(ticket),
    env.DB.prepare("DELETE FROM sessions WHERE expires_at <= ?1").bind(now),
  ]);
  return json({ ok: true, status: "authenticated", token, steamid64: row.steamid64, expires_at: now + SESSION_TTL });
}

export async function logout(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  if (session instanceof Response) return session;
  await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?1").bind(session.tokenHash).run();
  return json({ ok: true });
}

export async function whoAmI(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  if (session instanceof Response) return session;
  return json({ ok: true, steamid64: session.steamid64 });
}
