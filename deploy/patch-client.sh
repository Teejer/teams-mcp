#!/usr/bin/env bash
# Patches the globally installed @floriscornel/teams-mcp package so its
# default Azure app registration (client ID + tenant authority) points at
# our own Entra ID registration.
# Env in:  TEAMS_MCP_CLIENT_ID, TEAMS_MCP_TENANT_ID
# Note: client and tenant IDs are public identifiers, not secrets.
set -euo pipefail

PKG_DIR="$(npm root -g)/@floriscornel/teams-mcp"

if [[ ! -d "$PKG_DIR" ]]; then
  echo "ERROR: @floriscornel/teams-mcp not found at $PKG_DIR" >&2
  exit 1
fi

if [[ -z "${TEAMS_MCP_CLIENT_ID:-}" || -z "${TEAMS_MCP_TENANT_ID:-}" ]]; then
  echo "ERROR: TEAMS_MCP_CLIENT_ID and TEAMS_MCP_TENANT_ID must be set" >&2
  exit 1
fi

# Patches the hard-coded clientId and login authority literals in the
# package's dist output, whatever values the published version ships with:
#   const CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
#   const AUTHORITY = "https://login.microsoftonline.com/<guid-or-common>";
# The authority may ship as a concatenation (e.g. "https://login.microsoftonline.com/"
# + TENANT_ID), so we patch both a full URL literal and a bare-tenant literal.
# This keeps the patch working across upstream releases and avoids
# referencing any specific organization's identifiers in this repo.

# Runs as root at build time; the package is owned by root. If a future
# base image runs this as a non-root user, fail loudly instead of silently.
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: patch must run as root (npm -g install location)" >&2
  exit 1
fi

PATCH_FILE="$(mktemp)"
trap 'rm -f "$PATCH_FILE"' EXIT

patch_dist() {
  # $1 = ERE to find, $2 = sed replacement for that ERE
  # Note: uses command substitution (not a pipe) so the matches counter
  # survives — a pipeline would run the loop in a subshell.
  local matches=0 f files
  files="$(grep -rlE "$1" "$PKG_DIR/dist" 2>/dev/null || true)"
  for f in $files; do
    sed -E "$1" "$2" "$f" > "$PATCH_FILE" && cat "$PATCH_FILE" > "$f"
    matches=$((matches + 1))
  done
  [[ $matches -gt 0 ]] || { echo "WARNING: no dist files matched: $1" >&2; return 1; }
  return 0
}

patch_dist 'const CLIENT_ID = "[0-9a-f-]{36}"' \
  "s/const CLIENT_ID = \"[0-9a-f-]{36}\"/const CLIENT_ID = \"$TEAMS_MCP_CLIENT_ID\"/"

# Authority as one literal string: ".../login.microsoftonline.com/<guid>|common"
if ! patch_dist 'login\.microsoftonline\.com/(common|[0-9a-f-]{36})' \
  "s#login\\.microsoftonline\\.com/(common|[0-9a-f-]{36})#login.microsoftonline.com/$TEAMS_MCP_TENANT_ID#g"; then

  # Fallback: authority built from a URL prefix + a separate tenant literal
  patch_dist '(const TENANT_ID = )(common|"[0-9a-f-]{36}")' \
    "s\\1\"$TEAMS_MCP_TENANT_ID\"" || {
    echo "ERROR: could not locate clientId/authority literals in $PKG_DIR/dist — upstream format may have changed" >&2
    exit 1
  }
fi

# Point the login authority at our tenant (was /common)
grep -rl 'login\.microsoftonline\.com/common' "$PKG_DIR/dist" 2>/dev/null | \
  xargs -r sed -i "s|login\.microsoftonline\.com/common|login.microsoftonline.com/$TEAMS_MCP_TENANT_ID|g"

echo "Patched teams-mcp defaults:"
echo "  client_id -> $TEAMS_MCP_CLIENT_ID"
echo "  authority -> https://login.microsoftonline.com/$TEAMS_MCP_TENANT_ID"
