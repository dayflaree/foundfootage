import type { Env } from "./types";
import { finishSteamCallback, finishSteamLogin, logout, startSteamLogin, whoAmI } from "./auth";
import { adminFeed, changes, createMessage, createMessageFromServer, deleteMessage, myMessages, permanentlyDeleteMessage, reportMessage, serverIngestAuthorized, snapshot } from "./messages";
import { apiError, json } from "./utils";

function securityHeaders(response: Response): Response {
  const wrapped = new Response(response.body, response);
  wrapped.headers.set("x-content-type-options", "nosniff");
  wrapped.headers.set("referrer-policy", "no-referrer");
  return wrapped;
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const method = request.method.toUpperCase();

  if (method === "OPTIONS") return new Response(null, {
    status: 204,
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type, x-admin-token, x-server-token",
      "access-control-allow-methods": "GET, POST, DELETE, OPTIONS",
      "access-control-max-age": "86400",
    },
  });

  if (method === "GET" && url.pathname === "/") {
    return json({
      ok: true,
      service: "Found Footage global map messages",
      version: 1,
      endpoints: ["/health", "/v1/maps/:map/snapshot", "/v1/maps/:map/changes", "/v1/server/health", "/v1/server/messages", "/v1/admin/feed"],
    });
  }
  if (method === "GET" && url.pathname === "/health") {
    const row = await env.DB.prepare("SELECT 1 AS ready").first<{ ready: number }>();
    return json({ ok: row?.ready === 1, database: row?.ready === 1 ? "ready" : "unavailable" });
  }

  if (method === "GET" && url.pathname === "/v1/auth/start") return startSteamLogin(request, env);
  if (method === "GET" && url.pathname === "/v1/auth/callback") return finishSteamCallback(request, env);
  if (method === "GET" && url.pathname === "/v1/auth/finish") return finishSteamLogin(request, env);
  if (method === "POST" && url.pathname === "/v1/auth/logout") return logout(request, env);
  if (method === "GET" && url.pathname === "/v1/me") return whoAmI(request, env);
  if (method === "GET" && url.pathname === "/v1/me/messages") return myMessages(request, env);
  if (method === "GET" && url.pathname === "/v1/admin/feed") return adminFeed(request, env);

  if (method === "GET" && /^\/v1\/maps\/[^/]+\/snapshot$/.test(url.pathname)) return snapshot(request, env);
  if (method === "GET" && /^\/v1\/maps\/[^/]+\/changes$/.test(url.pathname)) return changes(request, env);
  if (method === "POST" && url.pathname === "/v1/messages") return createMessage(request, env);
  if (method === "POST" && url.pathname === "/v1/server/health") {
    if (!serverIngestAuthorized(request, env)) {
      return apiError(401, "server_authentication_required", "A valid Found Footage server token is required.");
    }
    await env.DB.prepare("SELECT 1 AS ready").first();
    return json({ ok: true, authenticated: true, database: "ready" });
  }
  if (method === "POST" && url.pathname === "/v1/server/messages") return createMessageFromServer(request, env);

  const permanentDeleteMatch = url.pathname.match(/^\/v1\/admin\/messages\/([0-9a-f-]{36})\/permanent$/i);
  if (method === "DELETE" && permanentDeleteMatch?.[1]) {
    return permanentlyDeleteMessage(request, env, permanentDeleteMatch[1]);
  }

  const messageMatch = url.pathname.match(/^\/v1\/messages\/([0-9a-f-]{36})$/i);
  if (method === "DELETE" && messageMatch?.[1]) return deleteMessage(request, env, messageMatch[1]);
  const reportMatch = url.pathname.match(/^\/v1\/messages\/([0-9a-f-]{36})\/report$/i);
  if (method === "POST" && reportMatch?.[1]) return reportMessage(request, env, reportMatch[1]);

  return apiError(404, "not_found", "No API route matches this request.");
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return securityHeaders(await route(request, env));
    } catch (error) {
      console.error("Unhandled request error", error);
      return securityHeaders(apiError(500, "internal_error", "The message service encountered an unexpected error."));
    }
  },
} satisfies ExportedHandler<Env>;
