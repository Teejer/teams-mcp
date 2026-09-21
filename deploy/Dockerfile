# syntax=docker/dockerfile:1
# Containerized teams-mcp (@floriscornel/teams-mcp) pre-configured for our
# Azure AD app registration. Build with deploy/build.sh (not by hand) so the
# client/tenant build args come from deploy/.env.
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-slim

ARG TEAMS_MCP_VERSION=latest
ARG TEAMS_MCP_CLIENT_ID
ARG TEAMS_MCP_TENANT_ID
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

# Bake our Azure app registration IDs into the installed package so the CLI
# and server default to our Entra tenant without extra env plumbing.
# (Client/tenant IDs are public identifiers, not secrets.)
COPY patch-client.sh /tmp/patch-client.sh
RUN TEAMS_MCP_CLIENT_ID="${TEAMS_MCP_CLIENT_ID}" \
    TEAMS_MCP_TENANT_ID="${TEAMS_MCP_TENANT_ID}" \
    bash /tmp/patch-client.sh && rm /tmp/patch-client.sh

# Staging directory for outbound file sends (bind-mount your host outbox here)
RUN mkdir -p /home/node/teams-outbox

USER node
WORKDIR /home/node

ENTRYPOINT ["teams-mcp"]
