#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$ROOT/../.." && pwd)"
WRANGLER_CONFIG="$ROOT/wrangler.jsonc"
GAMEMODE_CONFIG="${FOUNDFOOTAGE_CONFIG:-$REPOSITORY_ROOT/gamemode/configuration.lua}"
GARRYSMOD_DATA_ROOT="${FOUNDFOOTAGE_DATA_ROOT:-$REPOSITORY_ROOT/../../data}"
ADMIN_TOKEN_FILE="$ROOT/.admin-token"
SERVER_TOKEN_FILE="$GARRYSMOD_DATA_ROOT/foundfootage/map_messages_server_token.txt"

cd "$ROOT"

whoami_output="$(npx wrangler whoami 2>&1 || true)"
if grep -q "not authenticated" <<<"$whoami_output"; then
    printf '%s\n' \
        "Cloudflare authentication is required." \
        "Run: cd $ROOT && npx wrangler login" \
        "Then rerun: ./deploy-cloudflare.sh"
    exit 2
fi

npm run check
npm test

if grep -q '00000000-0000-0000-0000-000000000000' "$WRANGLER_CONFIG"; then
    echo "Creating the free D1 database..."
    create_output="$(npx wrangler d1 create foundfootage-messages --binding DB 2>&1)"
    printf '%s\n' "$create_output"
    database_id="$(grep -Eo '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' <<<"$create_output" | tail -n 1)"
    if [[ -z "$database_id" ]]; then
        echo "Could not extract the D1 database ID from Wrangler output." >&2
        exit 3
    fi
    python3 - "$WRANGLER_CONFIG" "$database_id" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
database_id = sys.argv[2]
text = path.read_text(encoding="utf-8")
placeholder = "00000000-0000-0000-0000-000000000000"
if placeholder in text:
    text = text.replace(placeholder, database_id, 1)
    path.write_text(text, encoding="utf-8")
elif database_id not in text:
    raise SystemExit("Wrangler updated the config with an unexpected database ID")
PY
fi

echo "Applying remote D1 migrations..."
# Wrangler automatically accepts this confirmation when stdin is noninteractive.
npx wrangler d1 migrations apply foundfootage-messages --remote </dev/null

if [[ ! -s "$ADMIN_TOKEN_FILE" ]]; then
    umask 077
    openssl rand -base64 48 | tr -d '\n' > "$ADMIN_TOKEN_FILE"
fi
chmod 600 "$ADMIN_TOKEN_FILE"

mkdir -p "$(dirname "$SERVER_TOKEN_FILE")"
if [[ ! -s "$SERVER_TOKEN_FILE" ]]; then
    umask 077
    openssl rand -base64 48 | tr -d '\n' > "$SERVER_TOKEN_FILE"
fi
chmod 600 "$SERVER_TOKEN_FILE"

echo "Creating the initial Worker deployment..."
initial_deploy_output="$(npx wrangler deploy 2>&1)"
printf '%s\n' "$initial_deploy_output"

echo "Installing the administrator secret..."
npx wrangler secret put ADMIN_TOKEN < "$ADMIN_TOKEN_FILE"

echo "Installing the GMod server-ingest secret..."
npx wrangler secret put SERVER_INGEST_TOKEN < "$SERVER_TOKEN_FILE"

echo "Deploying the final Worker version..."
deploy_output="$(npx wrangler deploy 2>&1)"
printf '%s\n' "$deploy_output"
worker_url="$(grep -Eo 'https://[A-Za-z0-9._-]+\.workers\.dev' <<<"$deploy_output" | tail -n 1)"
if [[ -z "$worker_url" ]]; then
    echo "Deployment completed, but the workers.dev URL could not be extracted." >&2
    echo "Put the deployed HTTPS URL in FF_CONFIG.MapMessages.APIBaseURL manually." >&2
    exit 4
fi

python3 - "$GAMEMODE_CONFIG" "$worker_url" <<'PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
url = sys.argv[2]
text = path.read_text(encoding="utf-8")
pattern = re.compile(r'(MapMessages\s*=\s*\{.*?APIBaseURL\s*=\s*)"[^"]*"', re.S)
updated, count = pattern.subn(lambda match: match.group(1) + f'"{url}"', text, count=1)
if count != 1:
    raise SystemExit("Could not locate FF_CONFIG.MapMessages.APIBaseURL")
path.write_text(updated, encoding="utf-8")
PY

health="$(curl -fsSL "$worker_url/health")"
printf '%s\n' \
    "" \
    "Found Footage global messages are deployed." \
    "Worker: $worker_url" \
    "Health: $health" \
    "Administrator token: $ADMIN_TOKEN_FILE" \
    "GMod server token: $SERVER_TOKEN_FILE" \
    "Gamemode configuration updated: $GAMEMODE_CONFIG"
