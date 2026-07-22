# Immediate message creation investigation

Research date: 2026-07-22

## Observed failure

The live D1 database showed:

- 0 messages
- 0 message events
- 0 authenticated sessions
- 1 unfinished authentication ticket

The unfinished ticket had no linked SteamID64 and no completion timestamp. The client therefore queued the message, opened the Steam OpenID URL, and never reached the authenticated `POST /v1/messages` request. The bottom-right notifications were status messages from that browser-authentication path.

## Why the browser existed

A central service cannot trust an arbitrary client-supplied SteamID64. Echoes Beyond solves that global identity problem with Steam OpenID in a browser. That provides a service-verifiable account identity across unrelated servers.

Found Footage's desired interaction is different: pressing `RECORD MESSAGE` should save immediately with no browser interruption.

## Garry's Mod capabilities researched

Garry's Mod exposes `Player:SteamID64()` in the server realm. It returns the connected player's 64-bit Steam community identifier as a string:

- https://wiki.facepunch.com/gmod/Player:SteamID64

Garry's Mod also exposes asynchronous `HTTP()` requests in the server realm:

- https://wiki.facepunch.com/gmod/Global.HTTP

The documented Lua API does not expose a general client Steam authentication ticket suitable for direct verification by this Worker. The practical no-browser trust boundary is therefore the current GMod server.

## Selected architecture

The current GMod server now performs the entire create operation:

1. The server traces and validates the cassette location.
2. It stores a short-lived placement record for that player.
3. The client sends only the message text when `RECORD MESSAGE` is activated.
4. The server reads `ply:SteamID64()` from the connected player.
5. The server submits the map, author, text, position, and normal to `POST /v1/server/messages`.
6. The request carries a private `X-Server-Token` header over HTTPS.
7. The Worker validates the token and applies the existing mute, cooldown, quota, message-length, map-name, coordinate, and spacing rules.
8. D1 inserts the message and create event.
9. The Worker returns the saved public record.
10. The GMod server immediately broadcasts that record to connected players.

The cassette appears after the Worker confirms the durable insert, normally within one network round trip. No browser, player token, or login notification is involved.

## Secret storage

The Worker secret is named:

`SERVER_INGEST_TOKEN`

The matching GMod server token is stored outside distributed gamemode source at:

`garrysmod/data/foundfootage/map_messages_server_token.txt`

The local file has mode `0600`. It must never be included in a Workshop package or public repository.

## Cross-server tradeoff

Every server can read global messages because map snapshots are public. A server can create messages only after receiving its own trusted server credential.

Allowing unknown third-party servers to create messages without browser authentication would require trusting an author SteamID64 supplied by an untrusted server. Malicious server operators could then forge authors and automate spam. Safe public expansion should issue separate revocable credentials per approved server.

## Live verification

A live integration test successfully:

- created a message through `POST /v1/server/messages`;
- exposed it through the public map snapshot;
- exposed its author SteamID64 through the private administrator feed;
- deleted it through the administrator endpoint;
- removed it from the public snapshot.

The integration test records were hard-deleted afterward. The production database returned to zero messages and zero events.
