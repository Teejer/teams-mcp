# Teams MCP — Container Deployment (WEI fork)

Fork of [floriscornel/teams-mcp](https://github.com/floriscornel/teams-mcp) — an MCP
(Model Context Protocol) server giving AI assistants full Microsoft Teams / Graph API
access (messages, chats, search, users, file uploads).

This fork keeps the upstream source untouched and adds **our deployment tooling**: a
Dockerfile and scripts that build a containerized teams-mcp pre-configured for our
Azure AD app registration, with an isolated file staging directory so agent hosts can
hand files to the container safely.

## What we added (see `deploy/`)

| File | Purpose |
|---|---|
| `deploy/Dockerfile` | Builds `teams-mcp` image: node:22 + npm package + our Azure client/tenant IDs |
| `deploy/build.sh` | Builds the image (reads IDs from `.env`) |
| `deploy/run.sh` | Starts the container with the right bind mounts |
| `deploy/authenticate.sh` | One-time device-code login into the container |
| `deploy/patch-client.sh` | Bakes our Azure app registration IDs into the installed package |
| `deploy/teams-mcp` | Host CLI wrapper we actually invoke |
| `deploy/.env.example` | Template for the build-time config (copy to `.env`) |
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
- An Azure AD (Entra ID) **app registration** with the Graph *delegated* permissions
  listed in [upstream README](#required-microsoft-graph-permissions) (see upstream
  README section "Required Microsoft Graph Permissions"). Note the **Application
  (client) ID** and **Directory (tenant) ID**.
- Public client flow must be enabled (device code flow) — no client secret is used.

## Quick start

```bash
# 1. Configure build-time IDs (these are identifiers, not secrets)
cp deploy/.env.example deploy/.env
$EDITOR deploy/.env          # set TEAMS_MCP_CLIENT_ID and TEAMS_MCP_TENANT_ID

# 2. Build the image
./deploy/build.sh            # -> teams-mcp:latest

# 3. Authenticate once (device code flow; tokens persist in bind-mounted files)
./deploy/authenticate.sh

# 4. Smoke test
./deploy/run.sh check
```

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

`set-dns.bat` and `set-dns.ps1` set primary/secondary DNS (10.10.1.27 / 10.10.1.30) on
Windows endpoints. Both require Administrator. The `.bat` targets adapters named
`Ethernet`/`Wi-Fi`; the `.ps1` auto-detects all connected physical adapters and is the
recommended version. They contain no credentials or secrets — edit the IP variables at
the top for your environment.

## Upstream

All credit for the MCP server itself to Floris Cornel and contributors. Keep this
fork current:

```bash
git fetch upstream && git merge upstream/main
```

## License

MIT (same as upstream).
