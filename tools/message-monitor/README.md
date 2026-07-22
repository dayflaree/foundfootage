# Found Footage Message Monitor

Native GTK desktop viewer for the private Found Footage Cloudflare administrator feed.

## Features

- Live polling every 10 seconds
- Message list with map, author SteamID64, text, timestamp, state, and report count
- Search and map filtering
- Active/deleted filtering
- Full coordinate, normal, timestamp, UUID, and report details
- Steam profile links
- Protected permanent deletion with an irreversible confirmation dialog
- Desktop notifications for newly created messages

## Security

The monitor reads the existing administrator token from the repository-local service directory:

`services/message-service/.admin-token`

The token is sent only in the `X-Admin-Token` HTTPS header to the configured Cloudflare Worker. It is never stored in the desktop launcher or printed to logs.

## Run

```bash
./run.sh
```

## Connectivity test

```bash
./run.sh --self-test
```

Environment overrides:

- `FOUNDFOOTAGE_MESSAGE_API`
- `FOUNDFOOTAGE_ADMIN_TOKEN_FILE`
