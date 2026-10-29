#!/usr/bin/env bash
# Runs the teams-mcp container. With no args it starts the MCP server over
# stdio (this is what MCP clients launch). Any args are passed through to the
# teams-mcp CLI (e.g. "check", "authenticate", "logout").
#
# Env:
#   TEAMS_MCP_IMAGE      image tag (default teams-mcp:latest)
#   TEAMS_MCP_READ_ONLY  "true" to start the server in read-only mode
#   TEAMS_MCP_CLIENT_ID  optional Entra app (client) ID; forwarded to the
#   TEAMS_MCP_TENANT_ID  container. Unset = upstream Graph CLI app default.
#                        IMPORTANT: whichever value authenticated the tokens
#                        must be used by BOTH this server and the CLI that
#                        ran `authenticate` — a mismatch means the server can
#                        never refresh the cached token ("Not authenticated"
#                        forever). See Troubleshooting in README.md.
#   OUTBOX_DIR           host directory staged into the container
#                        (default ~/teams-outbox)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
fi

IMAGE="${TEAMS_MCP_IMAGE:-teams-mcp:latest}"
OUTBOX="${OUTBOX_DIR:-$HOME/teams-outbox}"
AUTH_FILE="$HOME/.msgraph-mcp-auth.json"
CACHE_FILE="$HOME/.teams-mcp-token-cache.json"

# The container needs these files to exist to persist auth across runs.
# (Docker would otherwise recreate a missing bind-mount source as a
# root-owned directory and the server dies writing it.)
touch "$AUTH_FILE" "$CACHE_FILE"
mkdir -p "$OUTBOX"

ARGS=(
  run -i --rm --init
  --label teams-mcp-managed
  -v "$AUTH_FILE:/home/node/.msgraph-mcp-auth.json"
  -v "$CACHE_FILE:/home/node/.teams-mcp-token-cache.json"
  -v "$OUTBOX:/home/node/teams-outbox:ro"
)

if [[ "${TEAMS_MCP_READ_ONLY:-}" == "true" ]]; then
  ARGS+=(-e TEAMS_MCP_READ_ONLY=true)
fi

# Optional runtime app-registration override (must match the CLI's env).
if [[ -n "${TEAMS_MCP_CLIENT_ID:-}" ]]; then
  ARGS+=(-e "TEAMS_MCP_CLIENT_ID=${TEAMS_MCP_CLIENT_ID}")
fi
if [[ -n "${TEAMS_MCP_TENANT_ID:-}" ]]; then
  ARGS+=(-e "TEAMS_MCP_TENANT_ID=${TEAMS_MCP_TENANT_ID}")
fi

ARGS+=("$IMAGE" "$@")

exec docker "${ARGS[@]}"
