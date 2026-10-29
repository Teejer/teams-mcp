# Teams MCP — Container Deployment (WEI fork)

Fork of [floriscornel/teams-mcp](https://github.com/floriscornel/teams-mcp) — an MCP
(Model Context Protocol) server giving AI assistants full Microsoft Teams / Graph API
access (messages, chats, search, users, file uploads).

This fork keeps the upstream source untouched and adds **our deployment tooling**: a
Dockerfile and scripts that build a containerized teams-mcp (optionally pointed at
our Azure AD app registration via runtime env vars), with an isolated file staging
directory so agent hosts can hand files to the container safely.

## What we added

| File | Purpose |
|---|---|
| `deploy/Dockerfile` | Builds `teams-mcp` image: node:22 + npm package (TZ/version configurable) |
| `deploy/build.sh` | Builds the image (reads options from `.env`) |
| `deploy/run.sh` | Starts the container with the right bind mounts; forwards optional client/tenant IDs as runtime env |
| `deploy/authenticate.sh` | One-time device-code login into the container |
| `deploy/teams-mcp` | Host CLI wrapper we actually invoke |
| `deploy/.env.example` | Template for the runtime config (copy to `.env`) |
| `opencode/skills/teams-send-file/SKILL.md` | OpenCode skill teaching agents the outbox file-send workflow |
| `scripts/set-dns.bat` / `.ps1` | Example: a small ops script sent to Teams via the MCP |

## Architecture

```
AI agent host                       teams-mcp container (this image)
---------------                     --------------------------------
~/teams-outbox/  ──bind ro────────▶ /home/node/teams-outbox   <- stage files here
~/.msgraph-mcp-auth.json ─bind rw─▶ /home/node/...auth.json   <- auth metadata
~/.teams-mcp-token-cache.json ────▶ /home/node/...cache.json  <- refresh tokens
```

- The container runs as the non-root `node` user.
- **File sends only work for files under `/home/node/teams-outbox`.** Stage a file on
  the host (`cp myreport.pdf ~/teams-outbox/`), then call `send_file_to_chat` /
  `send_file_to_channel` with the **container** path
  (`/home/node/teams-outbox/myreport.pdf`). Clean up after sending.
- The agent host never needs network access to the container; it speaks MCP over
  stdio (`docker run -i`).

## Prerequisites

- Docker
- (Optional) An Azure AD (Entra ID) **app registration** with the Graph
  *delegated* permissions listed in [upstream README](#required-microsoft-graph-permissions)
  (see upstream README section "Required Microsoft Graph Permissions"). Note the
  **Application (client) ID** and **Directory (tenant) ID** and put them in
  `deploy/.env`. With them unset, everything uses the upstream default (Microsoft
  Graph CLI app). Public client flow must be enabled if you do register one —
  no client secret is used.

## Quick start

```bash
# 1. (Optional) Configure an app registration; unset = upstream default app
cp deploy/.env.example deploy/.env
$EDITOR deploy/.env          # set TEAMS_MCP_CLIENT_ID / TEAMS_MCP_TENANT_ID

# 2. Build the image
./deploy/build.sh            # -> teams-mcp:latest

# 3. Authenticate once (device code flow; tokens persist in bind-mounted files).
#    This uses the SAME deploy/.env values as the server, by design.
./deploy/authenticate.sh

# 4. Smoke test
./deploy/run.sh check
```

## Troubleshooting

- **`Not authenticated` forever despite successful `authenticate`** — the
  server refreshes tokens only from `~/.teams-mcp-token-cache.json` (the MSAL
  cache; `~/.msgraph-mcp-auth.json` is CLI metadata the server ignores), and
  MSAL can only refresh a token with the **same client id** that minted it.
  Older images baked a client id into the package with a sed patch, so a token
  minted by an unpatched CLI (or vice versa) could never be refreshed. Fixed
  by moving to upstream's runtime env vars — make sure `deploy/.env` is
  identical for `authenticate.sh` and `run.sh` (both source it), and
  `./deploy/run.sh logout` + re-authenticate after any change.
- **`teams-mcp check` succeeds but the MCP server still says
  `Not authenticated`** — expected when the client ids differ (see above);
  `check` reads the metadata file, the server uses the MSAL cache.
- **Server exits immediately with code 137 / EISDIR** — a bind-mount source
  (`~/.teams-mcp-token-cache.json`) is missing or a directory; `run.sh`
  `touch`es both files, don't delete them by hand.
- Tool calls failing with `Unexpected non-whitespace character after JSON at
  position …` — that was the pre-1.0 image throwing on every call while
  unauthenticated; rebuilding from this repo fixes it.

## Point your MCP client at it

```json
{
  "mcpServers": {
    "teams": {
      "command": "/path/to/this/repo/deploy/teams-mcp",
      "env": { "TEAMS_MCP_IMAGE": "teams-mcp:latest" }
    }
  }
}
```

`deploy/teams-mcp` launches the container with `-i --rm --init` and the three bind
mounts shown above. Set `TEAMS_MCP_READ_ONLY=true` there for a read-only deployment.

## Sending files (the gotcha we hit)

`send_file_to_chat` / `send_file_to_channel` take a **filePath inside the container**.
Paths on the agent host (or absolute paths outside the outbox) fail with `ENOENT`.

```bash
cp ~/Documents/report.pdf ~/teams-outbox/
# then: send_file_to_chat({ chatId, filePath: "/home/node/teams-outbox/report.pdf" })
rm ~/teams-outbox/report.pdf
```

## OpenCode skill (auto-discoverable workflow)

[`opencode/skills/teams-send-file/SKILL.md`](opencode/skills/teams-send-file/SKILL.md)
is an OpenCode skill that teaches any agent session the outbox staging workflow
above, so file sends just work without re-explaining the container paths.

Install it for the current user:

```bash
mkdir -p ~/.config/opencode/skills
cp -r opencode/skills/teams-send-file ~/.config/opencode/skills/
```

(For other MCP clients, the same content works as a system-prompt include or
project instructions file.)

## Security notes

- **No secrets are committed to this repo.** `deploy/.env` (git-ignored) holds only
  the Azure *client ID* and *tenant ID* — these are public identifiers, not secrets.
  Authentication is delegated device-code OAuth; refresh tokens live in
  `~/.teams-mcp-token-cache.json` on the host — **treat that file as a secret**, do
  not commit or share it.
- If you use the `AUTH_TOKEN` env var (pre-issued Graph JWT), pass it at runtime
  only — never bake it into an image.
- Prefer `TEAMS_MCP_READ_ONLY=true` for deployments that only need to read Teams.

## DNS helper scripts (`scripts/`)

`set-dns.bat` and `set-dns.ps1` set primary/secondary DNS on Windows endpoints.
Both require Administrator. The `.bat` targets adapters named `Ethernet`/`Wi-Fi`;
the `.ps1` auto-detects all connected physical adapters and is the recommended
version.

The scripts ship with **documentation IP addresses** (RFC 5737 TEST-NET-1:
`192.0.2.10` / `192.0.2.11`) — edit the variables at the top of each script
(`set PRIMARY=...` / `$Primary = ...`) to your real DNS servers before use.

## Upstream

All credit for the MCP server itself to Floris Cornel and contributors. Keep this
fork current:

```bash
git fetch upstream && git merge upstream/main
```

## License

MIT (same as upstream).
