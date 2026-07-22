# Found Footage global map-message service

A Cloudflare Worker and D1 database that provides permanent, map-specific messages to every Found Footage installation.

## Local validation

```bash
npm install
npm run check
npm test
npm run db:local
npm run dev
```

Then request `http://127.0.0.1:8787/health`.

## First deployment

1. Authenticate Wrangler with `npx wrangler login`.
2. Create the database:

   ```bash
   npx wrangler d1 create foundfootage-messages
   ```

3. Replace the placeholder `database_id` in `wrangler.jsonc` with the returned ID.
4. Apply migrations:

   ```bash
   npm run db:remote
   ```

5. Create an administrator token and store it as a Worker secret:

   ```bash
   openssl rand -base64 32 | npx wrangler secret put ADMIN_TOKEN
   ```

6. Deploy:

   ```bash
   npm run deploy
   ```

7. Put the resulting HTTPS Worker URL in `FF_CONFIG.MapMessages.APIBaseURL` in the gamemode.

## Message creation authentication

Normal message creation is server-mediated. The GMod server validates the world placement, reads the connected player's server-side `Player:SteamID64()`, and posts to `POST /v1/server/messages` with the private `SERVER_INGEST_TOKEN` in the `X-Server-Token` header. The player does not open a browser or manage a token.

`POST /v1/server/health` verifies the server credential and D1 binding without creating a message. The gamemode runs this check at startup and exposes it through the server command `ff_messages_diagnose`.

Server-side write attempts and failures are recorded as JSON Lines at:

`garrysmod/data/foundfootage/map_messages_server.log`

The log contains request stage, map, SteamID64, HTTP status, and sanitized Worker response details. It never records the server token.

The server token is stored outside the gamemode source at:

`garrysmod/data/foundfootage/map_messages_server_token.txt`

Steam OpenID remains available for optional player-owned account operations such as deleting a message from a different installation. It is not part of the normal record-message flow.

## Persistence model

Messages are keyed by the exact `game.GetMap()` name. D1 retains them until the author or an administrator deletes them. Public map reads omit author SteamIDs.

## Private administrator feed

`GET /v1/admin/feed?after=<event_cursor>&limit=<1-500>` returns the global create/delete event stream with full message records, including map name and author SteamID64. It requires the Worker `ADMIN_TOKEN` in the `X-Admin-Token` header. Public map endpoints continue to omit author identity.

`DELETE /v1/admin/messages/:id/permanent` irreversibly removes the message row, reports, author identity, coordinates, text, and prior event history. It then writes a content-free delete tombstone so active game servers remove the cassette. This route also requires `X-Admin-Token`.

The native Linux viewer source is included at:

`tools/message-monitor`

## Operations

Export D1 regularly from the Cloudflare dashboard or Wrangler. The service implements owner deletion, reports, mutes in the schema, per-player cooldowns, per-map quotas, and minimum spatial separation.
