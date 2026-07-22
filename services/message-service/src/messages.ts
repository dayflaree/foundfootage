import { requireSession } from "./auth";
import type { Env, PublicMessage, Vector3 } from "./types";
import { apiError, distanceSquared, isMapName, json, normalizeMessage, nowSeconds, parseInteger, parseVector } from "./utils";

const SNAPSHOT_PAGE_SIZE = 250;
const CHANGE_PAGE_SIZE = 250;
const POST_COOLDOWN_SECONDS = 30;
const MAX_ACTIVE_PER_MAP_PER_PLAYER = 25;
const MINIMUM_SPACING = 80;

interface MessageRow {
  sequence: number;
  id: string;
  body: string;
  position_x: number;
  position_y: number;
  position_z: number;
  normal_x: number;
  normal_y: number;
  normal_z: number;
  created_at: number;
  deleted_at: number | null;
}

function publicMessage(row: MessageRow): PublicMessage {
  return {
    id: row.id,
    body: row.body,
    position: { x: row.position_x, y: row.position_y, z: row.position_z },
    normal: { x: row.normal_x, y: row.normal_y, z: row.normal_z },
    created_at: row.created_at,
  };
}

function mapFromPath(pathname: string, suffix: string): string | null {
  const match = pathname.match(new RegExp(`^/v1/maps/([^/]+)/${suffix}$`));
  if (!match?.[1]) return null;
  try {
    const map = decodeURIComponent(match[1]);
    return isMapName(map) ? map : null;
  } catch {
    return null;
  }
}

export async function snapshot(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const map = mapFromPath(url.pathname, "snapshot");
  if (!map) return apiError(400, "invalid_map", "The map name is invalid.");
  const after = parseInteger(url.searchParams.get("after"), 0, 0, Number.MAX_SAFE_INTEGER);
  const limit = parseInteger(url.searchParams.get("limit"), SNAPSHOT_PAGE_SIZE, 1, SNAPSHOT_PAGE_SIZE);

  const [rowsResult, cursorRow] = await Promise.all([
    env.DB.prepare(
      `SELECT sequence, id, body, position_x, position_y, position_z, normal_x, normal_y, normal_z, created_at, deleted_at
       FROM messages WHERE map_name = ?1 AND sequence > ?2 ORDER BY sequence ASC LIMIT ?3`
    ).bind(map, after, limit).all<MessageRow>(),
    env.DB.prepare("SELECT COALESCE(MAX(event_id), 0) AS cursor FROM message_events WHERE map_name = ?1")
      .bind(map).first<{ cursor: number }>(),
  ]);

  const scanned = rowsResult.results ?? [];
  const messages = scanned.filter((row) => row.deleted_at == null).map(publicMessage);
  const nextAfter = scanned.length > 0 ? scanned[scanned.length - 1]!.sequence : after;
  return json({
    ok: true,
    map,
    messages,
    scan_cursor: nextAfter,
    event_cursor: Number(cursorRow?.cursor ?? 0),
    has_more: scanned.length === limit,
  });
}

interface EventRow extends MessageRow {
  event_id: number;
  event_type: "create" | "delete";
  message_id: string;
}

export async function changes(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const map = mapFromPath(url.pathname, "changes");
  if (!map) return apiError(400, "invalid_map", "The map name is invalid.");
  const after = parseInteger(url.searchParams.get("after"), 0, 0, Number.MAX_SAFE_INTEGER);
  const limit = parseInteger(url.searchParams.get("limit"), CHANGE_PAGE_SIZE, 1, CHANGE_PAGE_SIZE);

  const result = await env.DB.prepare(
    `SELECT e.event_id, e.event_type, e.message_id,
            m.sequence, m.id, m.body, m.position_x, m.position_y, m.position_z,
            m.normal_x, m.normal_y, m.normal_z, m.created_at, m.deleted_at
     FROM message_events e
     LEFT JOIN messages m ON m.id = e.message_id
     WHERE e.map_name = ?1 AND e.event_id > ?2
     ORDER BY e.event_id ASC LIMIT ?3`
  ).bind(map, after, limit).all<EventRow>();

  const rows = result.results ?? [];
  const events = rows.map((row) => row.event_type === "delete"
    ? { event_id: row.event_id, type: "delete" as const, message_id: row.message_id }
    : { event_id: row.event_id, type: "create" as const, message: publicMessage(row) });
  const nextCursor = rows.length > 0 ? rows[rows.length - 1]!.event_id : after;
  return json({ ok: true, map, events, cursor: nextCursor, has_more: rows.length === limit });
}

async function parseJsonBody(request: Request): Promise<Record<string, unknown> | null> {
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > 4096) return null;
  try {
    const value: unknown = await request.json();
    return value && typeof value === "object" ? value as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

interface CreateContext {
  steamid64: string;
  payload: Record<string, unknown>;
}

async function createMessageFor(context: CreateContext, env: Env): Promise<Response> {
  const { steamid64, payload } = context;
  const map = typeof payload.map === "string" ? payload.map : "";
  const body = normalizeMessage(payload.message);
  const position = parseVector(payload.position);
  const normal = parseVector(payload.normal, true);
  if (!isMapName(map)) return apiError(400, "invalid_map", "The map name is invalid.");
  if (!body) return apiError(400, "invalid_message", "Use 1-100 characters of text across at most four lines.");
  if (!position || !normal) return apiError(400, "invalid_position", "The world position or surface normal is invalid.");

  const now = nowSeconds();
  const muted = await env.DB.prepare(
    "SELECT 1 AS muted FROM mutes WHERE steamid64 = ?1 AND (expires_at IS NULL OR expires_at > ?2)"
  ).bind(steamid64, now).first();
  if (muted) return apiError(403, "muted", "This Steam account cannot create messages.");

  const recent = await env.DB.prepare(
    "SELECT created_at FROM messages WHERE author_steamid64 = ?1 ORDER BY created_at DESC LIMIT 1"
  ).bind(steamid64).first<{ created_at: number }>();
  if (recent && recent.created_at > now - POST_COOLDOWN_SECONDS) {
    return apiError(429, "posting_too_fast", `Wait ${recent.created_at + POST_COOLDOWN_SECONDS - now} seconds before leaving another message.`);
  }

  const count = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM messages WHERE author_steamid64 = ?1 AND map_name = ?2 AND deleted_at IS NULL"
  ).bind(steamid64, map).first<{ count: number }>();
  if (Number(count?.count ?? 0) >= MAX_ACTIVE_PER_MAP_PER_PLAYER) {
    return apiError(409, "map_quota_reached", `You already have ${MAX_ACTIVE_PER_MAP_PER_PLAYER} active messages on this map.`);
  }

  const nearby = await env.DB.prepare(
    `SELECT position_x, position_y, position_z FROM messages
     WHERE map_name = ?1 AND deleted_at IS NULL
       AND position_x BETWEEN ?2 AND ?3
       AND position_y BETWEEN ?4 AND ?5
       AND position_z BETWEEN ?6 AND ?7
     LIMIT 30`
  ).bind(
    map,
    position.x - MINIMUM_SPACING, position.x + MINIMUM_SPACING,
    position.y - MINIMUM_SPACING, position.y + MINIMUM_SPACING,
    position.z - MINIMUM_SPACING, position.z + MINIMUM_SPACING,
  ).all<Vector3 & { position_x: number; position_y: number; position_z: number }>();
  for (const row of nearby.results ?? []) {
    if (distanceSquared(position, { x: row.position_x, y: row.position_y, z: row.position_z }) < MINIMUM_SPACING * MINIMUM_SPACING) {
      return apiError(409, "too_close", "Another message is already too close to this location.");
    }
  }

  const id = crypto.randomUUID();
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO messages
       (id, map_name, author_steamid64, body, position_x, position_y, position_z,
        normal_x, normal_y, normal_z, created_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)`
    ).bind(id, map, steamid64, body, position.x, position.y, position.z, normal.x, normal.y, normal.z, now),
    env.DB.prepare(
      "INSERT INTO message_events (map_name, message_id, event_type, created_at) VALUES (?1, ?2, 'create', ?3)"
    ).bind(map, id, now),
  ]);

  return json({ ok: true, message: { id, body, position, normal, created_at: now } satisfies PublicMessage }, 201);
}

export async function createMessage(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  if (session instanceof Response) return session;
  const payload = await parseJsonBody(request);
  if (!payload) return apiError(400, "invalid_json", "A small JSON request body is required.");
  return createMessageFor({ steamid64: session.steamid64, payload }, env);
}

export function serverIngestAuthorized(request: Request, env: Env): boolean {
  const provided = request.headers.get("x-server-token");
  return Boolean(env.SERVER_INGEST_TOKEN && provided && provided === env.SERVER_INGEST_TOKEN);
}

export async function createMessageFromServer(request: Request, env: Env): Promise<Response> {
  if (!serverIngestAuthorized(request, env)) {
    return apiError(401, "server_authentication_required", "A valid Found Footage server token is required.");
  }

  const payload = await parseJsonBody(request);
  if (!payload) return apiError(400, "invalid_json", "A small JSON request body is required.");

  const steamid64 = typeof payload.author_steamid64 === "string" ? payload.author_steamid64 : "";
  if (!/^7656119\d{10}$/.test(steamid64)) {
    return apiError(400, "invalid_steamid64", "The author SteamID64 is invalid.");
  }

  return createMessageFor({ steamid64, payload }, env);
}

export function adminAuthorized(request: Request, env: Env): boolean {
  const provided = request.headers.get("x-admin-token");
  return Boolean(env.ADMIN_TOKEN && provided && provided === env.ADMIN_TOKEN);
}

interface AdminFeedRow {
  event_id: number;
  event_type: "create" | "delete";
  event_created_at: number;
  sequence: number;
  id: string;
  map_name: string;
  author_steamid64: string;
  body: string;
  position_x: number;
  position_y: number;
  position_z: number;
  normal_x: number;
  normal_y: number;
  normal_z: number;
  created_at: number;
  deleted_at: number | null;
  report_count: number;
}

export async function adminFeed(request: Request, env: Env): Promise<Response> {
  if (!adminAuthorized(request, env)) {
    return apiError(401, "admin_authentication_required", "A valid administrator token is required.");
  }

  const url = new URL(request.url);
  const after = parseInteger(url.searchParams.get("after"), 0, 0, Number.MAX_SAFE_INTEGER);
  const limit = parseInteger(url.searchParams.get("limit"), 250, 1, 500);

  const result = await env.DB.prepare(
    `SELECT e.event_id,
            e.event_type,
            e.created_at AS event_created_at,
            m.sequence,
            m.id,
            m.map_name,
            m.author_steamid64,
            m.body,
            m.position_x,
            m.position_y,
            m.position_z,
            m.normal_x,
            m.normal_y,
            m.normal_z,
            m.created_at,
            m.deleted_at,
            (SELECT COUNT(*) FROM reports r WHERE r.message_id = m.id) AS report_count
     FROM message_events e
     INNER JOIN messages m ON m.id = e.message_id
     WHERE e.event_id > ?1
     ORDER BY e.event_id ASC
     LIMIT ?2`
  ).bind(after, limit).all<AdminFeedRow>();

  const rows = result.results ?? [];
  const events = rows.map((row) => ({
    event_id: row.event_id,
    type: row.event_type,
    event_created_at: row.event_created_at,
    message: {
      sequence: row.sequence,
      id: row.id,
      map_name: row.map_name,
      author_steamid64: row.author_steamid64,
      body: row.body,
      position: {
        x: row.position_x,
        y: row.position_y,
        z: row.position_z,
      },
      normal: {
        x: row.normal_x,
        y: row.normal_y,
        z: row.normal_z,
      },
      created_at: row.created_at,
      deleted_at: row.deleted_at,
      report_count: Number(row.report_count ?? 0),
    },
  }));
  const cursor = rows.length > 0 ? rows[rows.length - 1]!.event_id : after;

  return json({
    ok: true,
    events,
    cursor,
    has_more: rows.length === limit,
  });
}

export async function deleteMessage(request: Request, env: Env, id: string): Promise<Response> {
  let steamid64: string | null = null;
  const isAdmin = adminAuthorized(request, env);
  if (!isAdmin) {
    const session = await requireSession(request, env);
    if (session instanceof Response) return session;
    steamid64 = session.steamid64;
  }

  const row = await env.DB.prepare(
    "SELECT map_name, author_steamid64, deleted_at FROM messages WHERE id = ?1"
  ).bind(id).first<{ map_name: string; author_steamid64: string; deleted_at: number | null }>();
  if (!row) return apiError(404, "message_not_found", "The message does not exist.");
  if (row.deleted_at != null) return json({ ok: true, already_deleted: true });
  if (!isAdmin && row.author_steamid64 !== steamid64) {
    return apiError(403, "not_owner", "Only the author or a service administrator can delete this message.");
  }

  const now = nowSeconds();
  await env.DB.batch([
    env.DB.prepare("UPDATE messages SET deleted_at = ?1 WHERE id = ?2 AND deleted_at IS NULL").bind(now, id),
    env.DB.prepare(
      "INSERT INTO message_events (map_name, message_id, event_type, created_at) VALUES (?1, ?2, 'delete', ?3)"
    ).bind(row.map_name, id, now),
  ]);
  return json({ ok: true, id, deleted_at: now });
}

export async function permanentlyDeleteMessage(request: Request, env: Env, id: string): Promise<Response> {
  if (!adminAuthorized(request, env)) {
    return apiError(401, "admin_authentication_required", "A valid administrator token is required.");
  }

  const row = await env.DB.prepare(
    "SELECT map_name FROM messages WHERE id = ?1"
  ).bind(id).first<{ map_name: string }>();
  if (!row) return apiError(404, "message_not_found", "The message does not exist.");

  const now = nowSeconds();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM reports WHERE message_id = ?1").bind(id),
    env.DB.prepare("DELETE FROM message_events WHERE message_id = ?1").bind(id),
    env.DB.prepare("DELETE FROM messages WHERE id = ?1").bind(id),
    env.DB.prepare(
      "INSERT INTO message_events (map_name, message_id, event_type, created_at) VALUES (?1, ?2, 'delete', ?3)"
    ).bind(row.map_name, id, now),
  ]);

  return json({ ok: true, id, permanently_deleted: true, deleted_at: now });
}

export async function reportMessage(request: Request, env: Env, id: string): Promise<Response> {
  const session = await requireSession(request, env);
  if (session instanceof Response) return session;
  const payload = await parseJsonBody(request);
  const reason = normalizeMessage(payload?.reason);
  if (!reason) return apiError(400, "invalid_reason", "Provide a brief report reason.");
  const exists = await env.DB.prepare("SELECT 1 AS found FROM messages WHERE id = ?1").bind(id).first();
  if (!exists) return apiError(404, "message_not_found", "The message does not exist.");
  await env.DB.prepare(
    "INSERT OR IGNORE INTO reports (message_id, reporter_steamid64, reason, created_at) VALUES (?1, ?2, ?3, ?4)"
  ).bind(id, session.steamid64, reason, nowSeconds()).run();
  return json({ ok: true });
}

export async function myMessages(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  if (session instanceof Response) return session;
  const url = new URL(request.url);
  const map = url.searchParams.get("map");
  if (map && !isMapName(map)) return apiError(400, "invalid_map", "The map name is invalid.");
  const query = map
    ? env.DB.prepare(
      `SELECT sequence, id, body, position_x, position_y, position_z, normal_x, normal_y, normal_z, created_at, deleted_at
       FROM messages WHERE author_steamid64 = ?1 AND map_name = ?2 ORDER BY created_at DESC LIMIT 100`
    ).bind(session.steamid64, map)
    : env.DB.prepare(
      `SELECT sequence, id, body, position_x, position_y, position_z, normal_x, normal_y, normal_z, created_at, deleted_at
       FROM messages WHERE author_steamid64 = ?1 ORDER BY created_at DESC LIMIT 100`
    ).bind(session.steamid64);
  const result = await query.all<MessageRow>();
  return json({ ok: true, messages: (result.results ?? []).map((row) => ({ ...publicMessage(row), deleted_at: row.deleted_at })) });
}
