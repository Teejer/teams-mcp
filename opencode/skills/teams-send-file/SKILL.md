---
name: teams-send-file
description: Use when the user asks to send a file to Teams (to a person, chat, or channel). Explains the teams-outbox staging directory and the container paths the teams MCP file tools require.
---

# Sending files to Teams

The teams MCP runs in Docker and can only read files under `/home/node/teams-outbox`
(read-only bind mount of `~/teams-outbox` on the host). Its file tools are:

- `teams.send_file_to_chat` — args: `chatId`, `filePath` (container path), optional `message`, `fileName`, `format`, `importance`
- `teams.send_file_to_channel` — args: `teamId`, `channelId`, `filePath`, same options

## Steps

1. **Stage the file** (host side). If the user gave a path, copy it into the outbox; skip if already there:
   ```sh
   cp "<host file>" ~/teams-outbox/
   ```
   For files generated in the session, write them directly to `~/teams-outbox/<name>`.

2. **Map the path**: host `~/teams-outbox/<name>` → container `/home/node/teams-outbox/<name>`.

3. **Find the target** (if not already known):
   - Person/chat: `teams.list_chats`, or `teams.search_users` + `teams.create_chat` for someone new.
   - Channel: `teams.list_teams` → `teams.list_channels`.

4. **Send** with the container path:
   ```
   teams.send_file_to_chat({ chatId, filePath: "/home/node/teams-outbox/<name>", message })
   ```

5. **Clean up** large staged files after a successful send:
   ```sh
   rm ~/teams-outbox/<name>
   ```

## Notes

- The MCP container must be enabled (off by default): ask the user to enable `teams` via `/mcp` if tools fail with "not connected".
- Files >4 MB upload via Graph upload sessions; this is slow — warn on very large files.
- Channel uploads land in the team's SharePoint folder; chat uploads in OneDrive; Teams shows them as attachments on the message.
