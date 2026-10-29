#!/usr/bin/env bash
# Builds the containerized teams-mcp image.
# Usage: ./deploy/build.sh [image-tag]   (default tag: teams-mcp:latest)
#
# Client/tenant IDs are NO LONGER baked in at build time — upstream >= 1.0.x
# reads TEAMS_MCP_CLIENT_ID / TEAMS_MCP_TENANT_ID from the environment at
# runtime (run.sh forwards them from deploy/.env). Leaving them unset uses
# the upstream default (Microsoft Graph CLI app, common authority).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
fi

TAG="${1:-teams-mcp:latest}"
VERSION="${TEAMS_MCP_VERSION:-latest}"
TZ_NAME="${TZ:-US/Mountain}"

docker build \
  -f "$SCRIPT_DIR/Dockerfile" \
  --build-arg TEAMS_MCP_VERSION="$VERSION" \
  --build-arg TZ="$TZ_NAME" \
  -t "$TAG" \
  "$SCRIPT_DIR"

echo "Built $TAG"
