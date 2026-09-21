#!/usr/bin/env bash
# Runs the teams-mcp container. With no args it starts the MCP server over
# stdio (this is what MCP clients launch). Any args are passed through to the
# teams-mcp CLI (e.g. "check", "authenticate", "logout").
#
# Env:
#   TEAMS_MCP_IMAGE      image tag (default teams-mcp:latest)
#   TEAMS_MCP_READ_ONLY  "true" to start the server in read-only mode
#   OUTBOX_DIR           host directory staged into the container
#                        (default ~/teams-outbox)
set -euo pipefail

IMAGE="${TEAMS_MCP_IMAGE:-teams-mcp:latest}"
OUTBOX="${OUTBOX_DIR:-$HOME/teams-outbox}"
AUTH_FILE="$HOME/.msgraph-mcp-auth.json"
CACHE_FILE="$HOME/.teams-mcp-token-cache.json"

# The container needs these files to exist to persist auth across runs.
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

ARGS+=("$IMAGE" "$@")

exec docker "${ARGS[@]}"
