# syntax=docker/dockerfile:1
# Containerized teams-mcp (@floriscornel/teams-mcp). Build with deploy/build.sh.
#
# Upstream >= 1.0.x reads TEAMS_MCP_CLIENT_ID / TEAMS_MCP_TENANT_ID from the
# environment at runtime, so this image no longer sed-patches the installed
# package. (The old bake-in approach silently broke the server whenever the
# CLI that performed `authenticate` used a different client id — the token in
# the shared cache can only be refreshed by the client that minted it. See
# Troubleshooting in README.md.)
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-slim

ARG TEAMS_MCP_VERSION=latest
ARG TZ=UTC

# CA certs for Graph API calls
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Timezone
RUN ln -snf /usr/share/zoneinfo/"$TZ" /etc/localtime && echo "$TZ" > /etc/timezone

# Install the MCP server globally
RUN npm install -g @floriscornel/teams-mcp@${TEAMS_MCP_VERSION}

# Staging directory for outbound file sends (bind-mount your host outbox here)
RUN mkdir -p /home/node/teams-outbox

USER node
WORKDIR /home/node

ENTRYPOINT ["teams-mcp"]
