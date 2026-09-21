#!/usr/bin/env bash
# Builds the containerized teams-mcp image with our Azure app registration IDs.
# Usage: ./deploy/build.sh [image-tag]   (default tag: teams-mcp:latest)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
fi

: "${TEAMS_MCP_CLIENT_ID:?Set TEAMS_MCP_CLIENT_ID in deploy/.env (Azure app registration Application ID)}"
: "${TEAMS_MCP_TENANT_ID:?Set TEAMS_MCP_TENANT_ID in deploy/.env (Azure Directory (tenant) ID)}"

TAG="${1:-teams-mcp:latest}"
VERSION="${TEAMS_MCP_VERSION:-latest}"
TZ_NAME="${TZ:-US/Mountain}"

docker build \
  -f "$SCRIPT_DIR/Dockerfile" \
  --build-arg TEAMS_MCP_VERSION="$VERSION" \
  --build-arg TEAMS_MCP_CLIENT_ID="$TEAMS_MCP_CLIENT_ID" \
  --build-arg TEAMS_MCP_TENANT_ID="$TEAMS_MCP_TENANT_ID" \
  --build-arg TZ="$TZ_NAME" \
  -t "$TAG" \
  "$SCRIPT_DIR"

echo "Built $TAG"
